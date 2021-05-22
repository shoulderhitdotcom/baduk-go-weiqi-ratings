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

const AI = ["FineArt(絶芸)", "Golaxy", "韓豆", "BADUKi", "LeelaZero", "GLOBIS-AQZ", "Baduki", "DolBaram", "Raynz", "AlphaGo"]
const INFREQUENT_THRESHOLD = 10

includet("utils.jl")

tbl = JDF.load("kifu-depot-games-with-sgf.jdf/") |> DataFrame
# select!(tbl, Not(:sgf))
# JDF.save("kifu-depot-games-with-sgf.jdf/", tbl)


tbl.date = parse.(Date, tbl.date)

# for easy testing
# from_date, to_date = mad-Day(364), mad
mad = maximum(tbl.date)
@time pings, games, white75_advantage, black65_advantage= estimate_rating(mad-Day(364), mad);
