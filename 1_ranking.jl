const PATH = "c:/git/baduk-go-weiqi-ratings/"
using Pkg; Pkg.activate(PATH); cd(PATH)
using Revise: includet
using DataFrames, DataFramesMeta
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
    @transform date = parse.(Date, :date)
    @transform komi_fixed = replace(
        :komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )
    @where in.(:komi_fixed, Ref((6.5, 7.5)))
    select!(Not([:sgf, :comp, :result, :kifu_link, :win_by, :komi]))
end


### the below two lines can be skipped under a target flow
JDF.save("kifu-depot-games-for-ranking.jdf/", tbl)
tbl = JDF.load("kifu-depot-games-for-ranking.jdf/") |> DataFrame

function estimate_ratings_and_save_records(tbl)
    # for easy testing
    # from_date, to_date = mad-Day(364), mad
    mad = maximum(tbl.date)

    pings, games, white75_advantage, black65_advantage, abnormal_players = estimate_rating(mad-Day(364), mad; tbl);
    # pings, games, abnormal_players = estimate_rating(mad-Day(364), mad; tbl);

    from_date, to_date = string.(extrema(games.date))

    CSV.write("records/$(to_date) pings.csv", pings)

    # pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad
    pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad
end

# for creating previous records
if false
    for date_filter in filter(x-> x <= Date("2016-06-19"), sort!(unique(tbl.date), rev=true))
        println(date_filter)
        tbl_earlier = @where(tbl, :date .<= date_filter)
        @time estimate_ratings_and_save_records(tbl_earlier)
    end
end

# @target pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad =
@time pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad =
    estimate_ratings_and_save_records(tbl);


const OFFSET = 3800-6.5/log(10)*400
#infrequent_threshold = 8

# @target should allow the return of a path where things are stored
# out_path = @target pings_for_md1 = @chain @watch(pings) begin
pings_for_md1 = @chain pings begin
   @transform eng_name_old = coalesce.(eng_name.(:name), Ref(""));
   @transform eng_name = "[" .* :eng_name_old .* "](./player-games-md/md/" .* :eng_name_old .* ".md)"
   @transform estimate_for_ranking = :estimate .- 1.97 .* :std_error
   @transform Rating = @. round(Int, :estimate * 400 / log(10) + OFFSET)
   @transform rating_for_ranking = @. round(Int, :estimate_for_ranking * 400 / log(10) + OFFSET)
   @transform rating_uncertainty = "±" .* string.(round.(Int, :std_error .* 400 ./ log(10)))
   sort!(:estimate_for_ranking, rev=true)
   @transform Rank = 1:length(:estimate_for_ranking)
end

# this can be skipped in target network
JDF.save("pings.jdf", pings_for_md1)

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


