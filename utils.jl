using RCall
using Missings: disallowmissing, skipmissing
using BadukGoWeiqiTools: NAMESDB

function eng_name(name)
    try
        NAMESDB[name]
    catch _
        return missing
    end
end


const AI = ["FineArt(絶芸)", "Golaxy", "韓豆", "BADUKi", "LeelaZero", "GLOBIS-AQZ", "Baduki", "DolBaram", "Raynz", "AlphaGo"]
const INFREQUENT_THRESHOLD = 10



function estimate_rating(from_date, to_date = from_date + Day(364); tbl)
    tbl_1yr = @chain tbl begin
        @where .!in.(:black, Ref(AI))
        @where .!in.(:white, Ref(AI))
        @where :who_win .!= "Void"
        @where from_date .<= :date .<= to_date
        #@where ((:black .!= "柯潔") .& (:white .!= "柯潔")) .| (:date .<= Date("2021-01-01")) # for assess ke jie form
    end

    all_players_before_filter = vcat(tbl_1yr.black, tbl_1yr.white) |> unique

    retained_at_least_one_win_one_loss = false

    while !retained_at_least_one_win_one_loss
        won_at_least_one_game = @chain tbl_1yr begin
            select([:black, :white, :who_win])
            @transform winner = ifelse.(:who_win .== "B", :black, :white)
            groupby(:winner)
            combine(nrow)
            @where :nrow .>= 1
            _.winner
        end

        lost_at_least_one_game = @chain tbl_1yr begin
            select([:black, :white, :who_win])
            @transform loser = ifelse.(:who_win .== "B", :white, :black)
            groupby(:loser)
            combine(nrow)
            @where :nrow .>= 1
            _.loser
        end

        before_nrow = nrow(tbl_1yr)

        # estimate their strengths
        tbl_1yr = @chain tbl_1yr begin
            # @where .!in.(:black, Ref(infrequents.name))
            # @where .!in.(:white, Ref(infrequents.name))

            @where in.(:black, Ref(won_at_least_one_game))
            @where in.(:white, Ref(won_at_least_one_game))
            @where in.(:black, Ref(lost_at_least_one_game))
            @where in.(:white, Ref(lost_at_least_one_game))
        end

        if nrow(tbl_1yr) == before_nrow
            retained_at_least_one_win_one_loss = true
        end
    end

    abnormal_players = setdiff(all_players_before_filter, vcat(tbl_1yr.black, tbl_1yr.white) |> unique)


    games_played = @chain DataFrame(name = vcat(tbl_1yr.white, tbl_1yr.black)) begin
        groupby(:name)
        combine(nrow => :n)
        sort!(:n, rev=true)
    end

    players = vcat(tbl_1yr.black, tbl_1yr.white) |> unique |> sort!

    # the + 2 is for estimation of 7.5 komi white advantage and 6.5 komi black advantage
    m = zeros(nrow(tbl_1yr), length(players)+2)

    for (row, i) in enumerate(indexin(tbl_1yr.black, players))
        m[row, i] += 1

        if tbl_1yr[row, :komi_fixed] == 6.5
            m[row, end] = 1
        end
    end

    for (row, i) in enumerate(indexin(tbl_1yr.white, players))
        m[row, i] -= 1
        if tbl_1yr[row, :komi_fixed] == 7.5
            m[row, end-1] = -1
        end
    end

    df = DataFrame(m, :auto)
    df.y = float.(tbl_1yr.who_win .== "B")

    CSV.write("tmp-df-pls-del.csv", df)

    R"""
        df = data.table::fread("tmp-df-pls-del.csv")
        #m = glm(y~.-1, df, family=binomial, start = rep(5, ncol(df)-1))
        m = glm(y~.-1, df, family=binomial)
        strengths = broom::tidy(m)
    """

    rm("tmp-df-pls-del.csv")

    @rget strengths

    # return strengths, players, games_played

    # tbl_for_sim1 = @chain tbl_1yr begin
    #     select([:black, :white, :who_win, :komi_fixed])
    # end


    # players = vcat(tbl_for_sim1.black, tbl_for_sim1.white) |> unique |> sort!

    # tbl_for_sim = @chain tbl_for_sim1 begin
    #     @transform p1 = Int.(indexin(:black, players))
    #     @transform p2 = Int.(indexin(:white, players))
    #     select!(Not([:black, :white]))
    #     @transform p11 = ifelse.(:who_win .== "B", :p1, :p2)
    #     @transform p22 = ifelse.(:who_win .== "B", :p2, :p1)
    #     @transform winner_75komi_white = (:komi_fixed .== 7.5) .& (:who_win .== "W")
    #     @transform loser_75komi_white = (:komi_fixed .== 7.5) .& (:who_win .== "B")
    #     @transform winner_65komi_black = (:komi_fixed .== 6.5) .& (:who_win .== "B")
    #     @transform loser_65komi_black = (:komi_fixed .== 6.5) .& (:who_win .== "W")
    #     select!(Not([:p1, :p2]))
    # end

    # P1::Vector{Int} = tbl_for_sim.p11
    # P2::Vector{Int} = tbl_for_sim.p22
    # winner_75komi_white::BitVector = tbl_for_sim.winner_75komi_white
    # loser_75komi_white::BitVector = tbl_for_sim.loser_75komi_white
    # winner_65komi_black::BitVector = tbl_for_sim.winner_65komi_black
    # loser_65komi_black::BitVector = tbl_for_sim.loser_65komi_black

    # function neg_log_lik(weights)
    #     s = 0.0
    #     l = length(weights)

    #     white_75_advantage = weights[end-1] .* (winner_75komi_white .- loser_75komi_white)
    #     black_65_advantage = weights[end] .* (winner_65komi_black .- loser_65komi_black)

    #     @vectorize for i in 1:length(P1)
    #         a = P1[i]
    #         b = P2[i]
    #         c = white_75_advantage[i]
    #         d = black_65_advantage[i]
    #         x = weights[a] - weights[b] + c + d
    #         s += log(1/(1+exp(-x)))
    #     end
    #     return -s
    # end

    # initialiaze at 5 then only SJS will be 10+
    # the +2 is for 7.5 komi as white & 6.5 komi as black
    # init_w = zeros(maximum(maximum.((P1, P2))) + 2) .+ 5 #rand(maximum(maximum.((P1, P2))))
    # init_w[end-1] = 0.0
    # init_w[end] = 0.0


    # @time opm = optimize(neg_log_lik, init_w, BFGS());
    # ping = opm.minimizer[1:end-2]

    # playing_power_ping = DataFrame(name = players, ping = ping)

    # pings =@chain playing_power_ping begin
    #     leftjoin(games_played, on = :name)
    #     sort!(:ping, rev=true)
    # end

    # return the abnormal players too
    # @chain abnormal_players begin
    #     DataFrame()
    # end

    pings = @chain strengths[1:end-2, :] begin
        @transform name = players
        leftjoin(games_played, on =:name)
        @transform estimate = disallowmissing(coalesce.(:estimate, 0.0))
        @transform std_error = disallowmissing(coalesce.(:std_error, mean(:std_error |> skipmissing)))
        @transform estimate_for_ranking = :estimate .- 1.97 .* :std_error
        sort!(:estimate_for_ranking, rev=true)
        @transform Rank = 1:length(:estimate_for_ranking)
    end

    pings, tbl_1yr, strengths.estimate[end-1], strengths.estimate[end], abnormal_players

    # pings, tbl_1yr,  opm.minimizer[end-1], opm.minimizer[end], abnormal_players
end