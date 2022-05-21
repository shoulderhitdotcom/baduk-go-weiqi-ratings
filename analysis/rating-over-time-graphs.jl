# this script tries to get the data to estimate the latest games
const PATH = @__DIR__
const WSPATH = "c:/weiqi/web-scraping/" # webscraping results path
using Pkg;
Pkg.activate(PATH);
cd(PATH);
using Revise: includet
using DataFrames, DataFrameMacros
using Chain: @chain
using Serialization: deserialize
using Dates: Date, Day
using StatsBase
# using TimeZones; TimeZones.build()
using JDF
using CSV
using Alert
using Revise: includet

using BadukGoWeiqiTools: load_namesdb
const NAMESDB = load_namesdb()

includet("../utils.jl")

# rating offset
const OFFSET = 3800 - 6.5 / log(10) * 400

using CSV, Statistics, DataFrames, DataFrameMacros, Chain, Dates

pings = JDF.load("../pings_hist.jdf") |> DataFrame

# mtd = maximum(pings.date)
# fromdate = mtd - Dates.Day(364)
avg_pings = @chain pings begin
    # @subset fromdate <= :date <= mtd
    @subset :Rating > 0
    groupby(:date)
    @combine(mean(log, :Rating))
    sort!(:date)
end

using Plots, StatsPlots
gr()

@chain avg_pings begin
    @subset year(:date) >= 2013
    plot(_.date, _.Rating_function)
end
# @df avg_pings plot(:date, :Rating_function)

a = @chain avg_pings begin
    @transform :rating_csum = @c accumulate(+, :Rating_function)
    @transform :rating_mean = @c :rating_csum ./ (1:length(:rating_csum))
    select([:date, :Rating_function, :rating_mean])
end

true_mean = a[end, :].rating_mean

@chain pings begin
    @subset :date >= Date(2019, 6, 1)
    leftjoin(a, on = :date)
    @transform :log_rating = log(max(:Rating, 1)) - :Rating_function + true_mean
    @subset :eng_name_old == "Shin Jinseo"
    plot(_.date, _.log_rating)
end

games = JDF.load("../kifu-depot-games-for-ranking.jdf/") |> DataFrame

function ma(v::AbstractVector, n::Int)
    s = sum(@view v[1:n])
    vcat(accumulate(+, @view v[1:n]), accumulate(+, v[n+1:end]) .+ s .- accumulate(+, v[1:end-n]))
end


b = @chain games begin
    @transform :dummy = 1
    stack([:black, :white], :date)
    groupby([:date, :value])
    combine(nrow)
    unstack(:date, :value, :nrow)
    coalesce.(0)
    sort!(:date)
    @aside cnames = setdiff(Symbol.(names(_)), [:date])
    # select([:date, Symbol("申眞諝")])
    transform(_, cnames .=> (col -> ma(col, 365)) .=> cnames)
    stack(cnames, :date)
    @subset :value > 11
end

@chain pings begin
    innerjoin(select(b, [:date, :variable]), on = [:date => :date, :name => :variable])
    # @subset :date >= Date(2019, 6, 1)
    leftjoin(a, on = :date)
    @transform :log_rating = log(max(:Rating, 1)) - :Rating_function + true_mean
    @subset :eng_name_old == "Ke Jie"
    plot(_.date, _.log_rating)
end

@chain pings begin
    innerjoin(select(b, [:date, :variable]), on = [:date => :date, :name => :variable])
    # @subset :date >= Date(2019, 6, 1)
    leftjoin(a, on = :date)
    @transform :log_rating = log(max(:Rating, 1)) - :Rating_function + true_mean
    @subset :eng_name_old == "Shin Jinseo"
    plot!(_.date, _.log_rating)
end

@chain pings begin
    innerjoin(select(b, [:date, :variable]), on = [:date => :date, :name => :variable])
    # @subset :date >= Date(2019, 6, 1)
    leftjoin(a, on = :date)
    @transform :log_rating = log(max(:Rating, 1)) - :Rating_function + true_mean
    @subset :eng_name_old == "Park Junghwan"
    plot!(_.date, _.log_rating)
end

# using FloatingTableView
# browse(avg_pings)
# browse(a)


mar = ma(avg_pings.Rating_function, 365)
avg_pings.ma_ratings = vcat(1:365, mar)

plot(mar)