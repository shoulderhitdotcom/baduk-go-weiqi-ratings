const PATH = "c:/git/baduk-go-weiqi-ratings/"
using Pkg; Pkg.activate(PATH); cd(PATH)
using Revise: includet
using DataFrames, DataFramesMeta
using Chain: @chain
using Serialization: deserialize
using Dates: Date, Day
using StatsBase
# using Optim: optimize, BFGS
using LoopVectorization
using JDF
using CSV
using Alert
using Revise: includet

includet("utils.jl")

if isdir("c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/")
    tbl_from_somewhere = JDF.load("c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/") |> DataFrame
    tbl_from_somewhere.date = parse.(Date, tbl_from_somewhere.date)
    tbl_from_somewhere.komi_fixed = replace(
        tbl_from_somewhere.komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )

    tbl_from_somewhere = @where(tbl_from_somewhere, in.(:komi_fixed, Ref((6.5, 7.5))))
    select!(tbl_from_somewhere, Not([:sgf, :comp, :result, :kifu_link, :win_by, :komi]))

    JDF.save("kifu-depot-games-for-ranking.jdf/", tbl_from_somewhere)
end

tbl = JDF.load("kifu-depot-games-for-ranking.jdf/") |> DataFrame;

tbl = @chain tbl begin
    @where :komi_fixed .== 6.5
    @transform! black = :black .* Ref("_black")
    @transform! white = :white .* Ref("_white")
end


function meh2(tbl)
    # for easy testing
    mad = maximum(tbl.date)

    pings, games, white75_advantage, black65_advantage, abnormal_players = estimate_rating(mad-Day(365*2-1), mad; tbl);

    from_date, to_date = string.(extrema(games.date))

    CSV.write("$(to_date) pings black white.csv", pings)

    # pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad
    pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad
end

@time pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad = meh2(tbl);

using BadukGoWeiqiTools: NAMESDB

function eng_name(name)
    try
        NAMESDB[name]
    catch _
        return missing
    end
end

const OFFSET = 3800-6.5/log(10)*400
#infrequent_threshold = 8

pings_for_md1 = @chain pings begin
#    @where :n .> infrequent_threshold
   @transform eng_name = coalesce.(eng_name.(:name), Ref(""));
   @transform estimate_for_ranking = :estimate .- 1.97 .* :std_error
   @transform Rating = @. round(Int, :estimate * 400 / log(10) + OFFSET)
   @transform rating_for_ranking = @. round(Int, :estimate_for_ranking * 400 / log(10) + OFFSET)
   @transform rating_uncertainty = "±" .* string.(round.(Int, :std_error .* 400 ./ log(10)))
   sort!(:estimate_for_ranking, rev=true)
   @transform Rank = 1:length(:estimate_for_ranking)
end

JDF.save("pings-black-white.jdf", pings_for_md1)
