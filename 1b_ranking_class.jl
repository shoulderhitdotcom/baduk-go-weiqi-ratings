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

# load the hitorical ratings
# and append the latest record onto it
pings_hist = JDF.load("pings_hist.jdf") |> DataFrame |> unique

max_date = maximum(pings_hist.date)

max_date - Day(364)

@chain pings_hist begin
    @subset max_date - Day(364) <= :date <= max_date
    groupby(:eng_name_old)
    @combine begin
        :best_rank = minimum(:Rank)
        :mean_rank = ceil(Int, mean(:Rank))
    end
    sort!(:mean_rank)
end

using DataFrameMacros
sjs_first_appeared_date=@chain pings_hist begin
    @subset :eng_name_old == "Shin Jinseo"
    @subset @c :date .==  minimum(:date)
    minimum(_.date)
end

@chain pings_hist begin
    @subset :date == sjs_first_appeared_date
end

# anchor the rating at the first date on which SJS appeared

where_cond = pings_hist.date .== sjs_first_appeared_date
pings_hist[!, :adjusted_rating] .= -1
pings_hist[where_cond, :adjusted_rating] = pings_hist[where_cond, :Rating]

pings_reset = pings_hist[where_cond, :]

dates = filter(date->date >= sjs_first_appeared_date, unique(pings_hist.date))

sort!(dates)

date, date1 = dates[1:2]

for (date, date1) in zip(dates[1:end-1], dates[2:end])
    println(date)
    global pings_reset

    older_data = @chain pings_hist begin
        @subset :date == date
    end
    newer_data = @chain pings_hist begin
        @subset :date == date1
    end

    c = @chain newer_data begin
        innerjoin(select(older_data, :name, :Rating=>:older_rating), on = :name)
        # keep the the top 100 players
        @subset (:Rank <= 100)
    end

    # fit the linear model
    m = lm(@formula(older_rating ~ -1 + Rating), c)

    # compute the adjusted rating
    newer_data[:, :adjusted_rating] = round.(Int, predict(m, newer_data))

    pings_reset = vcat(pings_reset, newer_data)
end

@chain pings_reset begin
   @subset :eng_name_old == "Shin Jinseo"
end

@chain pings_reset begin
   @subset :eng_name_old == "Lee Sedol"
end

@chain pings_reset begin
    @subset :eng_name_old != ""
    groupby(:eng_name_old)
    combine(df->begin
        maximum(abs, diff(sort(df, :date).Rating))
    end)
end

c1 = @chain c begin
    @transform :predicted_rating = round(Int, coef(m)[1]*:Rating)
end

using Plots

df1 = @chain pings_reset begin
   @subset :eng_name_old == "Park Junghwan"
end

plot(df1.date, df1.Rating)

df2 = @chain pings_reset begin
   @subset :eng_name_old == "Shin Jinseo"
end

plot!(df2.date, df2.Rating)

df3 = @chain pings_reset begin
   @subset :eng_name_old == "Ke Jie"
end

plot!(df3.date, df3.Rating)

df4 = @chain pings_reset begin
   @subset :eng_name_old == "Lee Sedol"
end

plot!(df4.date, df4.Rating)


pings_for_md = select(
    pings_for_md1,
    :Rank,
    :eng_name=>"Name",
    :Rating,
    :rating_uncertainty=>Symbol("Uncertainty"),
    :rating_for_ranking => Symbol("5% CI Lower Bound Rating for ranking"),
    :n=>"Games Played",
    :name=>"Hanzi (汉字) Name")

JDF.save("pings_for_md.jdf", pings_for_md)

# CSV.write("c:/data/tmp.csv", pings_for_md)


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


