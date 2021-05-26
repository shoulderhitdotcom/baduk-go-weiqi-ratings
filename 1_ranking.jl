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

tbl = JDF.load("kifu-depot-games-for-ranking.jdf/") |> DataFrame


function meh(tbl)
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
        @time meh(tbl_earlier)
    end
end

#pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad = meh(tbl)
@time pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date, mad = meh(tbl);

#JDF.save("pings.jdf/", pings)


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

JDF.save("pings.jdf", pings_for_md1)

pings_for_md = select(pings_for_md1, :Rank, :eng_name=>"Name", :Rating, :rating_uncertainty=>Symbol("Uncertainty"), :rating_for_ranking => Symbol("5% CI Lower Bound Rating for ranking"), :n=>"Games Played", :name=>"Hanzi (汉字) Name")

JDF.save("pings_for_md.jdf", pings_for_md)

replacements = (
    "{{ngames}}" => string(nrow(games)),
    "{{from_date}}" =>from_date,
    "{{to_date}}" => to_date,
    "{{elo_white75_adv}}" => string(round(Int, white75_advantage*400/log(10))),
    "{{elo_black65_adv}}" => string(round(Int, black65_advantage*400/log(10))),
    "{{ping_white75_adv}}" => string(round(white75_advantage, digits=2)),
    "{{ping_black65_adv}}" => string(round(black65_advantage, digits=2)),
    "Ke Jie" => "[Ke Jie](kejie.md)",
)

using Weave

weave("index.jmd", out_path = "index-tmp.md", doctype = "github")

open("index-tmp.md") do file
    outfile = open("index.md", "w")
    while !eof(file)
        line = readline(file)
        for (in, replace_with) in replacements
            line = replace(line, in=>replace_with)
        end
        if line != "```"
            write(outfile, line)
            write(outfile, "\n")
        end
    end
    close(outfile)
end

rm("index-tmp.md")


try
    run(`git add index.md`)
    run(`git commit -m "daily update $to_date"`)
    run(`git push`)
    alert("Seems to have succeeded")
catch e
    alert("You process failed")
    raise(e)
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


