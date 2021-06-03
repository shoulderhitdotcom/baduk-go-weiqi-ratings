using RCall
using Missings: disallowmissing, skipmissing
using BadukGoWeiqiTools: load_namesdb

const NAMESDB = load_namesdb("NAMESDB")


function eng_name(name)
    try
        NAMESDB[name]
    catch _
        return missing
    end
end


const AI = ["FineArt(絶芸)", "Golaxy", "韓豆", "BADUKi", "LeelaZero", "GLOBIS-AQZ", "Baduki", "DolBaram", "Raynz", "AlphaGo"]
const INFREQUENT_THRESHOLD = 10

function prep_data(from_date, to_date, tbl)
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

    df, tbl_1yr, games_played, players, abnormal_players
end

function estimate_rating(from_date, to_date = from_date + Day(364); tbl)
    df, tbl_1yr, games_played, players, abnormal_players = prep_data(from_date, to_date, tbl)

    CSV.write("tmp-df-pls-del.csv", df)

    R"""
        df = data.table::fread("tmp-df-pls-del.csv")
        #m = glm(y~.-1, df, family=binomial, start = rep(5, ncol(df)-1))
        m = glm(y~.-1, df, family=binomial)
        strengths = broom::tidy(m)
    """

    rm("tmp-df-pls-del.csv")

    @rget strengths


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
end