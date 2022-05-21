using Base: beginsym
const PATH = "c:/git/baduk-go-weiqi-ratings/"
using Pkg; Pkg.activate(PATH); cd(PATH)
using Revise: includet
using DataFrames, DataFrameMacros
using Chain: @chain
using Serialization: deserialize
using Dates: Date, Day
using StatsBase
using JDF
using CSV
using Alert
using Revise: includet
using Dates

includet("utils.jl")

const dvalues = Dates.value

function get_infrequent_players(tbl, threshold)
    @chain vcat(tbl.black, tbl.white) begin
            DataFrame(names = _)
            groupby(:names)
            combine(nrow)
            @subset :nrow <= threshold
            _.names
    end
end


# the intended syntax
# @target = tbl = @chain @watch_path "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin

tbl = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
    JDF.load()
    DataFrame()
    @transform :who_win = uppercase(strip(:who_win))
    @subset :who_win != "VOID"
    @transform :date = parse(Date, :date)
    @transform :komi_fixed = @c replace(
        :komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )
    @subset in(:komi_fixed, (6.5, 7.5))
    select!(Not([:sgf, :comp, :result, :kifu_link, :win_by, :komi]))
    sort!(:date, rev=true)
    @subset !in(:black, AI)
    @subset !in(:white, AI)
    @transform :black = replace(:black, " "=>"")
    @transform :white = replace(:white, " "=>"")
    @transform :black = @c replace(:black, "郭信驛"=>"郭信駅")
    @transform :black = @c replace(:black, "陳梓建"=>"陳梓健")
    @transform :white = @c replace(:white, "郭信驛"=>"郭信駅")
    @transform :white = @c replace(:white, "陳梓建"=>"陳梓健")
    @transform :black = uppercase(:black)
    @transform :white = uppercase(:white)
    @subset !in(:black, AI)
    @subset !in(:white, AI)
    # @subset length(:black) < 6 # remove doubles
    # @subset length(:white) < 6 # remove doubles
end

# only build to the date where 朴廷桓 first appeared
cutoff_date = @chain tbl begin
    @subset (:black == "朴廷桓") | (:white == "朴廷桓")
    sort(_.date)[1]
end

tbl = @subset tbl :date >= cutoff_date

# find all those games that will impact Shin Jinseo's score
# @chain tbl begin
#     @subset (get(NAMESDB, :black, "") == "Shin Jinseo") | (get(NAMESDB, :black, "") == "Shin Jinseo")
# end

names = ["申眞諝"]
""" Keep only games that will be relevant for the names listed"""
function subset_closed_group(tbl, names)
    all_names = sort!(unique(vcat(tbl.black, tbl.white)))

    m = zeros(Int, length(all_names), length(all_names))
    for (i,j) in zip(1:length(all_names), 1:length(all_names))
        m[i, j] = 1
    end

    @chain tbl begin
        @transform :blackidx = @c indexin(:black, all_names)
        @transform :whiteidx = @c indexin(:white, all_names)
        @aside for (i,j) in zip(_.blackidx, _.whiteidx)
            m[i, j] = 1
            m[j, i] = 1
        end
    end

    v= zeros(Int, length(all_names))
    v[indexin(names, all_names)] .= 1

    last_sum = sum(v)
    done = false

    while !done
        v = min.(m*v, 1)
        if last_sum == sum(v)
            done =true
        else
            last_sum = sum(v)
        end

    end

    connected_to_sjs = all_names[v.==1]

    @chain tbl begin
        @subset :black in connected_to_sjs
        @subset :white in connected_to_sjs
        # @transform :winner = ifelse(:who_win == "B", :black, :white)
    end
end

tbl = subset_closed_group(tbl, names)


# number of unique players is 1880
println(vcat(tbl.white, tbl.black) |> unique |> length)

# get rid of infrequent players
const INFREQ_THRESHOLD = 6
infrequent_players = get_infrequent_players(tbl, INFREQ_THRESHOLD)
has_more_infrequent_players = true

while has_more_infrequent_players
    # compute the ratio of # apppears vs years\
    ratio_summ = @chain tbl begin
        select(:date, :black, :white)
        stack([:white, :black], :date)
        @groupby :value
        @combine(:min_date = minimum(:date), :max_date = maximum(:date), :nrow = length(:date))
        @transform :days = dvalues(Day(:max_date - :min_date))
        @transform :ratio = :nrow / :days
        # @aside println(@subset(_, :value == "許一笛"))
        @aside min_ratio_val = minimum(@subset(_, :value in ("洪爽義", "詹宜典", "金禹丞", "許一笛")).ratio)
        @subset :ratio < min_ratio_val
        # @subset :ratio < 0.0121
        @subset isfinite(:ratio)
        sort!(:ratio)
    end

    infrequent_players_by_ratio = ratio_summ.value

    tbl = @chain tbl begin
        @transform :winner = ifelse(:who_win == "B", :black, :white)
        @transform :loser = ifelse(:who_win == "B", :white, :black)
        @aside at_least_one_win_one_loss = intersect(Set(_.winner), Set(_.loser))
        @subset in(:black, at_least_one_win_one_loss)
        @subset in(:white, at_least_one_win_one_loss)
        @subset !in(:black, infrequent_players)
        @subset !in(:white, infrequent_players)
        @subset !in(:black, infrequent_players_by_ratio)
        @subset !in(:white, infrequent_players_by_ratio)
    end

    n = @chain DataFrame(name=vcat(tbl.black, tbl.white)) begin
        groupby(:name)
        combine(DataFrames.nrow)
        sort!(:nrow)
        @aside println(first(_, 100))
        # @aside println(@subset(_, :name =="許一笛"))
        @subset :nrow == 1
        nrow()
    end

    infrequent_players = get_infrequent_players(tbl, INFREQ_THRESHOLD)

    has_more_infrequent_players = (n > 0) | (length(infrequent_players) > 0)
end

@chain DataFrame(name=vcat(tbl.black, tbl.white)) begin
    groupby(:name)
    combine(nrow)
    sort!(:nrow)
end

@subset tbl :black == "洪爽義"
@subset tbl :white == "洪爽義"
@subset tbl :black == "許一笛"
@subset tbl :white == "許一笛"
@subset tbl :black == "沈沛然"
@subset tbl :white == "沈沛然"
@subset tbl :black == "金禹丞"
@subset tbl :white == "金禹丞"


player_names = (vcat(tbl.black, tbl.white) |> unique) |> sort!
filter(x->length(x)==6, player_names)

# keep only players with at least one win and one loss


# build the data
latest_date, model_end_date = sort!(unique(tbl.date), rev=true)[1:2]


# dataset to build model with
tbl_model = @subset tbl (:date >= cutoff_date) & (:date <= model_end_date)

tbl_test = @subset tbl (:date >= cutoff_date) & (:date ==latest_date)

# filter the models data a little
tbl_model = subset_closed_group(tbl_model, vcat(tbl_test.white, tbl_test.black) |> unique)
# buiild a model on the above data
using CUDA, Flux
CUDA.allowscalar(false)

function make_games(tbl_model, all_tbl_model_names)
    l = length(all_tbl_model_names)
    # the +2 are for komi 6.5 vs 7.5 as black and white respectively
    games= zeros(Int8, nrow(tbl_model), l+2);
    @chain tbl_model begin
        @aside for (row, (n1, n2, komi)) in enumerate(zip(_.black, _.white, _.komi_fixed))
            idx = indexin([n1], all_tbl_model_names)[1]
            idy = indexin([n2], all_tbl_model_names)[1]
            games[row, idx] = 1
            games[row, idy] = -1
            if komi == 6.5
                games[row, l+2] = 1
            elseif komi == 7.5
                games[row, l+1] = -1
            else
                error("invalid komi detected")
            end
        end
    end;
    games
end


using Flux:logitbinarycrossentropy

function loss_test(x, y)
    logitbinarycrossentropy(x, y)
end

decay_val = Float32(0.99)
function fit_strengths(tbl_model, decay_val::Float32, tbl_test)
    all_tbl_model_names = sort!(unique(vcat(tbl_model.black,tbl_model.white)))

    l = length(all_tbl_model_names)

    # initialise models weights to 0
    w = zeros(Float32, l+2) |> cu

    p = Flux.params(w)

    model(games) = games*w

    games = make_games(tbl_model, all_tbl_model_names) |> cu
    days_ago = round.(Int32, Int32.(Dates.value.(maximum(tbl_model.date) .- tbl_model.date)) ./ (365.25/30)) |> cu

    y = (tbl_model.winner .== tbl_model.black) |> cu

    decay_rates = decay_val .^ days_ago

    function loss2(x, y, decay_rates)
        logitbinarycrossentropy(model(x), y, agg=z->mean(decay_rates .* z))
    end

    # CUDA.@time loss2(games, y, decay_rates)
    # CUDA.@time loss2(games, y, decay_rates)

    opt2=ADAM()
    CUDA.@time Flux.train!(loss2, p, [(games, y, decay_rates)], opt2) # prime the training
    CUDA.@time Flux.train!(loss2, p, [(games, y, decay_rates)], opt2) # prime the training

    y_test = (tbl_test.winner .== tbl_test.black) |> cu
    games_test = make_games(tbl_test, all_tbl_model_names) |> cu

    while true
        last_loss = loss2(games, y, decay_rates)
        for _ in 1:100
            Flux.train!(loss2, p, [(games, y, decay_rates)], opt2)
        end

        new_loss = loss2(games, y, decay_rates)
        # println("loss: $(new_loss); test loss: $(loss_test(model(games_test), y_test))")

        if abs(new_loss - last_loss) < 10*eps(Float32)
            # break
            return loss_test(model(games_test), y_test)
        else
            last_loss = new_loss
        end
    end

    # cw = collect(w)

    # sort!(DataFrame(
    #     date = maximum(tbl_model.date),
    #     names = all_tbl_model_names,
    #     strength = cw[1:end-2],
    #     black65_adv = cw[end],
    #     white75_adv = cw[end-1],
    #     order = 1:length(all_tbl_model_names)
    # ), :strength, rev=true),
    #     (collect(games_test), collect(y_test))
end

using Optim

using Optim: Brent

@time optimize(decay_val-> fit_strengths(tbl_model, decay_val, tbl_test), 0+eps(Float32), 1-eps(Float32))

decay_val = 0.99 |>  Float32
CUDA.@time fit_strengths(tbl_model, decay_val, tbl_test)

decay_val = 1 |> Float32
CUDA.@time ok1, _ = fit_strengths(tbl_model, decay_val, tbl_test)

decay_val = 0.5 |> Float32
@time ok,_ = fit_strengths(tbl_model, decay_val, tbl_test)




all(ok.strength .== ok1.strength)


decay_val = 1f32
@time fit_strengths(tbl_model, decay_val, tbl_test)


decay_val = 0.90f32
fit_strengths(tbl_model, decay_val, tbl_test)


m, y, players = estimate_rating(mad-Day(364), mad; tbl);

@time estimate_rating(mad-Day(364), mad; tbl);

using CUDA
CUDA.allowscalar(false)

using Flux: Dense

nc = size(m,2)
cm = cu(m |> transpose |> collect)

model = Flux.Chain(
    Dense(zeros(1, nc) .+ 5, false),
    x-> 1 ./ (1 .+ exp.(-x)),
    vec
) |> gpu

function loss(cm, cy)
    p = model(cm)
    -sum(cy.*log.(p) + (1 .- cy).* log.(1 .- p))
end

function train!(cm, cy; maxit=100_000)
    last_loss = loss(cm, cy)
    opt = ADAM()
    @time for i in 1:maxit
        if mod(i, 1000) == 0
            new_loss = loss(cm, cy)
            if (last_loss - new_loss) < 0.01
                println("$i iterations ran")
                return params(model)[1] |> vec |> cpu
            else
                last_loss = new_loss
            end
        end
        Flux.train!(loss, params(model), [(cm, cy)], opt)
    end
end

@time ping = train!(cm, cy);

df = DataFrame(name = players, ping = strength)


