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

tbl_from_somewhere = JDF.load("c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/") |> DataFrame
tbl_from_somewhere.date = parse.(Date, tbl_from_somewhere.date)
tbl_from_somewhere.komi_fixed = replace(
    tbl_from_somewhere.komi,
    6.4 => 6.5,
    8.0 => 7.5,
    750 => 7.5,
    605.0 => 6.5
)

df = @where(tbl_from_somewhere, in.(:komi_fixed, Ref((6.5, 7.5))))

kejie = @chain df begin
    @transform black = eng_name.(:black)
    @transform white = eng_name.(:white)
    @where ("Ke Jie" .== :black) .| ("Ke Jie".== :white)
    sort!(:date, rev=true)
    @transform kifu = "[Kifu](https://kifudepot.org/" .* :kifu_link .* ")"
    select!(Not([:sgf, :komi, :who_win, :win_by, :kifu_link]))
end

JDF.save("./player-games/kejie.jdf", kejie)

using Weave

weave("kejie.jmd", out_path = "kejie.md", doctype = "github")

