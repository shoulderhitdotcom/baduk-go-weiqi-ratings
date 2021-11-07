## this script computes the ranking based on the latest data
const PATH = @__DIR__
const WSPATH = "c:/weiqi/web-scraping/" # webscraping results path
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

# rating offset
const OFFSET = 3800-6.5/log(10)*400

tbl = JDF.load("kifu-depot-games-for-ranking.jdf/") |> DataFrame


# for easy testing
using Dates
to_date = maximum(tbl.date) - Dates.Day(1)
from_date = to_date-Day(364)

pings, games, white75_advantage, black65_advantage, abnormal_players = estimate_rating(from_date, to_date; tbl);

sort!(select(pings, [:name, :estimate]), :estimate, rev=true)

# only update rating for those who has played
mtd = maximum(tbl.date)-Day(3)
played_today = @chain tbl begin
    @subset :date == mtd
    vcat(_.black, _.white)
    sort!()
end

@chain tbl1 begin
    @subset :black == played_today[7]
end

using Statistics: mean
tbl1 = @chain tbl begin
    # @subset (:black in played_today) | (:white in played_today)
    # @subset (from_date + Dates.Day(1) <= :date) & (:date <= mtd)
    # @subset (from_date <= :date) & (:date <= mtd)
    @transform :win = :who_win == "B" ? 1 : 0
    # groupby([:black, :white, :komi_fixed])
    # @combine(:win=mean(:win))
    # merge on the basis of player
    innerjoin(select(pings, :name, :estimate=>:black_rating), on=:black=>:name)
    innerjoin(select(pings, :name, :estimate=>:white_rating), on=:white=>:name)
    @transform :white_adv = ifelse(:komi_fixed==7.5, white75_advantage, 0)
    @transform :cc = ifelse(:black in played_today, 0.0, :black_rating) - ifelse(:white in played_today, 0.0, :white_rating)-:white_adv
    #@transform :d = exp(:cc)
    # @transform :win = :who_win == "B" ? 1 : 0
    #@transform :q = :win/(-(:d*:win)+:d+:win)
    sort!(:cc)
    @subset !ismissing(:cc)
end

#played_today1 = intersect(played_today, vcat(tbl1.black, tbl1.white))

played_today1 = unique(vcat(tbl1.black, tbl1.white))


tbl2 = DataFrame(
    (sort(played_today1) .== permutedims(tbl1.black)) - (sort(played_today1) .== permutedims(tbl1.white)) |>
        transpose, :auto)


tbl3 = @chain hcat(tbl1, tbl2) begin
    select(r"^x", :win, :cc)
end

using GLM

f = Term(:win) ~ ConstantTerm(-1) + sum(Term(Symbol("x$i")) for i in 1:length(played_today1))


m = glm(f, tbl3, Binomial(), offset=tbl3.cc .|> float)

sort!(DataFrame(names=played_today1, rating = coef(m)./log(10).*400 .+ OFFSET), :rating, rev=true)

xx = tbl3.cc

@rput xx

using RCall
tbl3 = select(tbl3, Not(:cc))
@rput tbl3
R"""
#tbl3 = data.frame(tbl3)
#xx = unlist(tbl3[["const"]])
#co = coef(glm(win~., data=tbl3, family=binomial #offset=xx))
co = coef(glm(win~-1+., data=tbl3, family=binomial, offset=xx))
"""


new_rating_est = @rget co
# 2-element Vector{Float64}:
#  6.10659926333693
#  6.654066039804406
# 6.09299842232976
# 6.602614489229113

@chain pings begin
    @subset :name in played_today
end


