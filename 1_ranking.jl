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

includet("utils.jl")

# the intended syntax
# @target = tbl = @chain @watch_path "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
tbl = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
    JDF.load()
    DataFrame()
    @transform :date = parse(Date, :date)
    @transform :komi_fixed = @c replace(
        :komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )
    @subset :komi_fixed in (6.5, 7.5)
    select!(Not([:sgf, :comp, :result, :kifu_link, :win_by, :komi]))
end


### the below two lines can be skipped under a target flow
JDF.save("kifu-depot-games-for-ranking.jdf/", tbl)
tbl = JDF.load("kifu-depot-games-for-ranking.jdf/") |> DataFrame

function estimate_ratings_and_save_records(tbl)
    # for easy testing
    to_date = maximum(tbl.date)
    from_date = to_date-Day(364)

    pings, games, white75_advantage, black65_advantage, abnormal_players = estimate_rating(from_date, to_date; tbl);

    from_date, to_date = string.(extrema(games.date))

    CSV.write("records/$(to_date) pings.csv", pings)

    pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date
end

# for creating previous records
if false
    for date_filter in filter(x-> x <= Date("2016-06-19"), sort!(unique(tbl.date), rev=true))
        println(date_filter)
        tbl_earlier = @subset(tbl, :date <= date_filter)
        @time estimate_ratings_and_save_records(tbl_earlier)
    end
end

@time pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date =
    estimate_ratings_and_save_records(tbl);


const OFFSET = 3800-6.5/log(10)*400
#infrequent_threshold = 8

# @target should allow the return of a path where things are stored
# out_path = @target pings_for_md1 = @chain @watch(pings) begin

function turn_records_into_md(pings)
    @chain pings begin
        @transform :name = @c Vector{String}(:name) # avoid weird SentinelArray Bug
        @transform :eng_name_old = coalesce(eng_name(:name), "");
        @transform :eng_name = "[" * :eng_name_old * "](./player-games-md/md/" * :eng_name_old * ".md)"
        @transform :estimate_for_ranking = :estimate - 1.97 * :std_error
        @transform :Rating = round(Int, :estimate * 400 / log(10) + OFFSET)
        @transform :rating_for_ranking = round(Int, :estimate_for_ranking * 400 / log(10) + OFFSET)
        @transform :rating_uncertainty = "±" * string(round(Int, :std_error * 400 / log(10)))
        sort!(:estimate_for_ranking, rev=true)
        @transform :Rank = @c 1:length(:estimate_for_ranking)
    end
end

# make ratings database
if false# run only once to generate the historical ratings
    @time pings_hist = mapreduce(vcat, Date(2001, 1, 1):Day(1):Date(2021,6,20)) do date
        if isfile("records/$(string(date)) pings.csv")
            pings_old = CSV.read("records/$(string(date)) pings.csv", DataFrame; select=[:name, :estimate, :std_error])
            pings_old[!, :date] .= date
            return select!(turn_records_into_md(pings_old), :date, :name, :eng_name_old, :Rating, :Rank)
        else
            return DataFrame()
        end
    end
    JDF.save("pings_hist.jdf", pings_hist)
end

pings_for_md1 = turn_records_into_md(pings)
# this can be skipped in target network
JDF.save("pings.jdf", pings_for_md1)

# add the date for appending to historical
pings_for_md1[!, :date] .= Date.(to_date)

# load the hitorical ratings
# and append the latest record onto it
pings_hist = JDF.load("pings_hist.jdf") |> DataFrame
pings_hist = unique(vcat(pings_hist, select( pings_for_md1, :date, :name, :eng_name_old, :Rating, :Rank)))
JDF.save("pings_hist.jdf", pings_hist)

pings_for_md = select(
    pings_for_md1,
    :Rank,
    :eng_name=>"Name",
    :Rating,
    :rating_uncertainty=>Symbol("Uncertainty"),
    :rating_for_ranking => Symbol("5% CI Lower Bound Rating for ranking"),
    :n=>"Games Played",
    :name=>"Hanzi (汉字) Name")

JDF.save("pings_for_md.jdf", pings_for_md)

CSV.write("c:/data/tmp.csv", pings_for_md)

using ParallelKMeans: kmeans

m = kmeans(reshape(Float64.(pings_for_md.Rating), 1, :), 10)
pings_for_md.m = m.assignments


@chain pings_for_md begin
    select(:Name, :Rating, :m)
end

## make a GLM solution
## Doesn't work

# players = vcat(games.black, games.white) |> unique |> sort!

# m = zeros(nrow(games), length(players))

# for (row, i) in enumerate(indexin(games.black, players))
#     m[row, i] += 1
# end

# for (row, i) in enumerate(indexin(games.white, players))
#     m[row, i] -= 1
# end

# df = DataFrame(m, :auto)
# df.y = float.(games.who_win .== "B")

# CSV.write("c:/data/ok.csv", df)

# using GLM: Term, glm, Binomial, LogitLink

# form = mapreduce(Term, + , [Symbol("x"*string(i)) for i in 1:length(players)])

# @time glm(Term(:y)~form, df, Binomial(), LogitLink());


