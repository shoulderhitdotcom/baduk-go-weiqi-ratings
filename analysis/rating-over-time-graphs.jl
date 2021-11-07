# this script tries to get the data to estimate the latest games
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

using BadukGoWeiqiTools: load_namesdb
const NAMESDB=load_namesdb()

includet("utils.jl")

# rating offset
const OFFSET = 3800-6.5/log(10)*400

using CSV, Statistics, DataFrames, DataFrameMacros, Chain, Dates

pings = JDF.load("pings_hist.jdf") |> DataFrame

mtd = maximum(pings.date)
fromdate = mtd - Dates.Day(364)

@chain pings begin
    @subset fromdate <= :date <= mtd
    groupby([:name, :eng_name_old])
    @combine minimum(:Rank) maximum(:Rank)
    sort!([:Rank_minimum, :Rank_maximum])
end

tblw = @chain tbl begin
    @subset fromdate <= :date <= mtd
    @transform :winner = ifelse(:who_win == "B", :black, :white)
    @transform :loser = ifelse(:who_win == "B", :white, :black)
    groupby(:winner)
    combine(nrow)
    @subset :nrow >= 2
end

tblb = @chain tbl begin
    @subset fromdate <= :date <= mtd
    @transform :winner = ifelse(:who_win == "B", :black, :white)
    @transform :loser = ifelse(:who_win == "B", :white, :black)
    groupby(:loser)
    combine(nrow)
    @subset :nrow >= 2
end

tbl = @chain tbl begin
    @subset :white in intersect(tblw.winner, tblb.loser)
    @subset :black in intersect(tblw.winner, tblb.loser)
end

# for easy testing
using Dates
to_date = maximum(tbl.date) - Dates.Day(1)
from_date = to_date-Day(364)

pings, games, white75_advantage, black65_advantage, abnormal_players = estimate_rating(from_date, to_date; tbl);


using FloatingTableView
browse(pings)


# normal every group

ping_normal_coefs = @chain pings begin
    @subset :Rank <= 100
    groupby(:date)
    @combine(:mean_rating = mean(:Rating), :std_rating = std(:Rating))
end


using Plots, StatsPlots

ping_normal_coefs1 = @chain ping_normal_coefs begin
    @subset Dates.year(:date) > 2010
end

sjs_rating = @chain pings begin
    @subset Dates.year(:date) >= 2015
    @subset :eng_name_old == "Shin Jinseo"
    leftjoin(ping_normal_coefs, on=:date)
    @transform(:normalised_rating = (:Rating - :mean_rating)/:std_rating)
end

# impute the ratings
# mindate, maxdate = extrema(sjs_rating.date)

# using DataFrames, Dates
# sjs_rating_imputed = @chain DataFrame(date = mindate:Dates.Day(1):maxdate) begin
#     leftjoin(sjs_rating, on=:date)
#     unique(:date)
#     sort!(:date)
# end

# for i in 2:nrow(sjs_rating_imputed)-1
#     if ismissing(sjs_rating_imputed.normalised_rating[i])
#         if !ismissing(sjs_rating_imputed.normalised_rating[i-1]) & !ismissing(sjs_rating_imputed.normalised_rating[i+1])
#             sjs_rating_imputed.normalised_rating[i] = (sjs_rating_imputed.normalised_rating[i-1]+sjs_rating_imputed.normalised_rating[i+1])
#         else
#             sjs_rating_imputed.normalised_rating[i] = sjs_rating_imputed.normalised_rating[i-1]
#         end
#     end
# end

# using CSV

# CSV.write("c:/data/sjs_rating.csv", sjs_rating_imputed)

# using RCall

# @rput sjs_rating_imputed
# R"""
# l = length(sjs_rating$normalised_rating)
# x = ts(sjs_rating$normalised_rating, frequency=365)
# xx = decompose(x)
# """;

# @rget xx

# plot(xx[:trend])
# plot!(xx[:seasonal])
# plot!(xx[:random])

# Vector(xx[:trend])

# xx[:trend][365:700]

# xx[:trend][end-365:end]

# countmap(xx[:trend])


plot(sjs_rating.date, sjs_rating.normalised_rating, label="Shin Jinseo", legend=:bottomright)

kj_rating = @chain pings begin
    @subset Dates.year(:date) >= 2015
    @subset :eng_name_old == "Ke Jie"
    leftjoin(ping_normal_coefs, on=:date)
    @transform(:normalised_rating = (:Rating - :mean_rating)/:std_rating)
end

plot!(kj_rating.date, kj_rating.normalised_rating, label="Ke Jie")

pjh_rating = @chain pings begin
    @subset Dates.year(:date) >= 2015
    @subset :eng_name_old == "Park Junghwan"
    leftjoin(ping_normal_coefs, on=:date)
    @transform(:normalised_rating = (:Rating - :mean_rating)/:std_rating)
end


plot!(pjh_rating.date, pjh_rating.normalised_rating, label="Park Junghwan")

pjh_rating = @chain pings begin
    @subset Dates.year(:date) >= 2015
    @subset :eng_name_old == "Byun Sangil"
    leftjoin(ping_normal_coefs, on=:date)
    @transform(:normalised_rating = (:Rating - :mean_rating)/:std_rating)
end

plot!(pjh_rating.date, pjh_rating.normalised_rating, label="Byun Sangil")

pjh_rating = @chain pings begin
    @subset Dates.year(:date) >= 2015
    @subset :eng_name_old == "Ding Hao"
    leftjoin(ping_normal_coefs, on=:date)
    @transform(:normalised_rating = (:Rating - :mean_rating)/:std_rating)
end

plot!(pjh_rating.date, pjh_rating.normalised_rating, label="Ding Hao")



# plot all those who has achieved number 1 ever

@chain pings begin
    @subset :Rank == 1
    _.eng_name_old
    unique
end

@chain pings begin
    @subset :Rank == 1
    _.eng_name_old
    unique
end