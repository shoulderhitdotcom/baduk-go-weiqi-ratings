const PATH = "c:/git/baduk-go-weiqi-ratings/"

using Pkg; Pkg.activate(PATH); cd(PATH)
using DataFrames, DataFramesMeta, Chain
using Serialization: deserialize
using Dates: Date, Day
using StatsBase
using Optim: optimize, BFGS
using LoopVectorization
using JDF

using Revise: includet

includet("utils.jl")

if !isdir("kifu-depot-games-with-sgf.jdf/")
    tbl = JDF.load("c:/weiqi/simulation/kifu-depot-games-with-sgf.jdf/") |> DataFrame
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

    JDF.save("kifu-depot-games-with-sgf.jdf/", tbl)
end

tbl = JDF.load("kifu-depot-games-with-sgf.jdf/") |> DataFrame

# for easy testing
# from_date, to_date = mad-Day(364), mad
mad = maximum(tbl.date)
@time pings, games, white75_advantage, black65_advantage= estimate_rating(mad-Day(364), mad; tbl);

using Weave

weave("index.jmd", out_path = "index-tmp.md", doctype = "github")

open("index-tmp.md") do file
    outfile = open("index.md", "w")
    while !eof(file)
        line = readline(file)
        if line != "```"
            write(outfile, line)
            write(outfile, "\n")
        end
    end
    close(outfile)
end

rm("index-tmp.md")
