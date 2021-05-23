const PATH = "c:/git/baduk-go-weiqi-ratings/"
using Pkg; Pkg.activate(PATH); cd(PATH)
using Revise: includet
using DataFrames, DataFramesMeta, Chain
using Serialization: deserialize
using Dates: Date, Day
using StatsBase
using Optim: optimize, BFGS
using LoopVectorization
using JDF

using Revise: includet

includet("utils.jl")

if !isdir("kifu-depot-games-for-ranking.jdf/")
    tbl = JDF.load("c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/") |> DataFrame
    tbl.date = parse.(Date, tbl.date)
    tbl.komi_fixed = replace(
        tbl.komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )

    tbl = @where(tbl, in.(:komi_fixed, Ref((6.5, 7.5))))
    select!(tbl, Not([:sgf, :comp, :result, :kifu_link, :win_by, :komi]))

    JDF.save("kifu-depot-games-for-ranking.jdf/", tbl)
end

tbl = JDF.load("kifu-depot-games-for-ranking.jdf/") |> DataFrame

# for easy testing
# from_date, to_date = mad-Day(364), mad
mad = maximum(tbl.date)
@time pings, games, white75_advantage, black65_advantage= estimate_rating(mad-Day(364), mad; tbl);

from_date, to_date = string.(extrema(games.date))

JDF.save("pings.jdf/", pings)


replacements = (
    "{{ngames}}" => string(nrow(games)),
    "{{from_date}}" =>from_date,
    "{{to_date}}" => to_date,
    "{{elo_white75_adv}}" => string(round(Int, white75_advantage*400/log(10))),
    "{{elo_black65_adv}}" => string(round(Int, black65_advantage*400/log(10))),
    "{{ping_white75_adv}}" => string(round(white75_advantage, digits=2)),
    "{{ping_black65_adv}}" => string(round(black65_advantage, digits=2)),
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

using Alert: alert
try
    run(`git add index.md`)
    run(`git commit -m "daily update $to_date"`)
    run(`git push`)
catch e
    println(e)
    alert()
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

# using GLM: Term, glm, Binomial, LogitLink

# form = mapreduce(Term, + , [Symbol("x"*string(i)) for i in 1:length(players)])

# @time glm(Term(:y)~form, df, Binomial(), LogitLink());


