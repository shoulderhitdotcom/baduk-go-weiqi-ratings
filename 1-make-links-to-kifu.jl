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

df = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
    JDF.load()
    DataFrame
    @transform date = parse.(Date, :date)
    @transform komi_fixed = replace(
        :komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5)
    @where in.(:komi_fixed, Ref((6.5, 7.5)))
    @transform black = eng_name.(:black)
    @transform white = eng_name.(:white)
    sort!(:date, rev=true)
    @transform kifu = "[Kifu](https://kifudepot.net/" .* :kifu_link .* ")"
    select!(Not([:sgf, :komi, :who_win, :win_by, :kifu_link]))
end

# for each player create the players's page
for name in vcat(df.black, df.white) |> unique
    if !ismissing(name)
        @chain df begin
            @where (:black .== name) .| (:white .== name)
            JDF.save("./player-games/$name.jdf", _)
        end
    end
end





