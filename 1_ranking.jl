## this script computes the ranking based on the latest data
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
using JDF
using CSV
using Alert
using Revise: includet

includet("utils.jl")

# rating offset
const NGAME_THRESHOLD = 11

# the intended syntax
# @target = tbl = @chain @watch_path "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
tbl = @chain joinpath(WSPATH, "kifu-depot-games-with-sgf.jdf/") begin
    JDF.load()
    DataFrame()
    @transform :date = parse(Date, :date)
    @transform :komi_fixed = @c replace(
        :komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )
    @subset :komi_fixed in (6.5, 7.5)
    select!(Not([:sgf, :comp, :result, :kifu_link, :win_by, :komi]))
    @transform :black = replace(:black, "羋昱廷" => "芈昱廷")
    @transform :white = replace(:white, "羋昱廷" => "芈昱廷")
end

@assert !("羋昱廷" in tbl.black)
@assert !("羋昱廷" in tbl.white)

### the below two lines can be skipped under a target flow
JDF.save("kifu-depot-games-for-ranking.jdf/", tbl)
tbl = JDF.load("kifu-depot-games-for-ranking.jdf/") |> DataFrame

function estimate_ratings_and_save_records(tbl)
    # for easy testing
    to_date = maximum(tbl.date)
    from_date = to_date - Day(364)

    (pings, games, white75_advantage, black65_advantage, abnormal_players) =
        estimate_rating(from_date, to_date; tbl)

    from_date, to_date = string.(extrema(games.date))

    CSV.write("records/$(to_date) pings.csv", pings)

    pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date
end

# are there missing dates in the database
dates_in_files = Date.(first.(split.(readdir("records"), " ")))
first_date, last_date = extrema(dates_in_files)

missing_dates = setdiff(
    sort(unique(tbl.date)),
    dates_in_files)

# back fill the missing dates in the last 365 days
for date_filter in filter(x -> x >= maximum(tbl.date) - Day(364), missing_dates)
    println(date_filter)
    tbl_earlier = @subset(tbl, :date <= date_filter)
    @time estimate_ratings_and_save_records(tbl_earlier)
end

# for creating previous records
if false
    for date_filter in filter(x -> x <= Date("2021-09-01"), sort!(unique(tbl.date), rev = true))
        println(date_filter)
        tbl_earlier = @subset(tbl, :date <= date_filter)
        @time estimate_ratings_and_save_records(tbl_earlier)
    end
end

@time pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date =
    estimate_ratings_and_save_records(tbl);

#infrequent_threshold = 8

# @target should allow the return of a path where things are stored
# out_path = @target pings_for_md1 = @chain @watch(pings) begin

# download the ratings from goratings and do a regression
using TableScraper
goratings_latest = scrape_tables("https://goratings.org/en")[2] |> DataFrame

goratings_latest = @chain goratings_latest begin
    @transform :elo = parse(Int, :Elo)
    select(:Name, :elo)
end

pings_for_alignment = @chain pings begin
    @transform :eng_name = get(NAMESDB, :name, "")
    @subset :eng_name != ""
    innerjoin(goratings_latest, on=:eng_name=>:Name)
    @transform :diff = :elo - :estimate * 400/log(10)
    sort!(:elo, rev=true)
    select(:eng_name, :elo, :diff)
    _[1, :]
end

function turn_records_into_md(pings)
    @chain pings begin
        @transform :name = @c Vector{String}(:name) # avoid weird SentinelArray Bug
        @transform :eng_name_old = coalesce(eng_name(:name), "")
        @transform :eng_name = "[" * :eng_name_old * "](./player-games-md/md/" * :eng_name_old * ".md)"
        # @transform :estimate_for_ranking = :estimate - 1.97 * :std_error
        # @transform :Rating = round(Int, :estimate * 400 / log(10) + OFFSET)
        # @transform :rating_for_ranking = round(Int, :estimate_for_ranking * 400 / log(10) + OFFSET)
        # @transform :rating_uncertainty = "±" * string(round(Int, :std_error * 400 / log(10)))
        @transform :Rating = round(Int, :estimate * 400 / log(10) + pings_for_alignment.diff)
        @transform :rating_uncertainty = "±" * string(round(Int, :std_error * 400 / log(10)))
        sort!(:Rating, rev = true)
        # @transform :Rank = @c 1:length(:Rating)
    end
end

# make ratings database
if false# run only once to generate the historical ratings
    @time pings_hist = mapreduce(vcat, Date(2001, 1, 1):Day(1):Date(2021, 7, 5)) do date
        # @time pings_hist = mapreduce(vcat, missing_dates) do date
        if isfile("records/$(string(date)) pings.csv")
            pings_old = CSV.read("records/$(string(date)) pings.csv", DataFrame; select = [:name, :estimate, :std_error])
            pings_old[!, :date] .= date
            return select!(turn_records_into_md(pings_old), :date, :name, :eng_name_old, :Rating)
        else
            return DataFrame()
        end
    end
    JDF.save("pings_hist.jdf", pings_hist)
end

pings_for_md1 = turn_records_into_md(pings)
# this can be skipped in target network
JDF.save("pings.jdf", pings_for_md1)

# add the date for appending to historical
pings_for_md1[!, :date] .= Date.(to_date)

# load the hitorical ratings
# and append the latest record onto it
pings_hist = JDF.load("pings_hist.jdf") |> DataFrame
cols_to_keep = [:date, :name, :eng_name_old, :Rating]
pings_hist = unique(vcat(pings_hist, select(pings_for_md1, cols_to_keep)), [:date, :name, :eng_name_old])

JDF.save("pings_hist.jdf", pings_hist)

# to make sure that the ratings don't slide crazily up and down we need to smooth it over time
# we smooth by picking out players who've played more than 10 games

# find out the number of games played in last 365 days
function ma365(col::AbstractVector)
    s = sum(@view col[1:365])
    a = accumulate(+, @view col[1:365])
    vcat(a, s .- accumulate(+, col[1:end-365]) .+ accumulate(+, col[366:end]))
end

games_played_hist = @chain tbl begin
    select(:date, :black, :white)
    stack([:black, :white], :date)
    select(:date, :value)
    groupby([:date, :value])
    combine(nrow => :n)
    groupby(:value)
    combine(df -> begin
        if nrow(df) >= 366
            return @chain df begin
                sort(:date)
                @transform :n = @c ma365(:n)
            end
        else
            return DataFrame()
        end
    end)
    @subset :n >= NGAME_THRESHOLD
    select(:value => :name, :date)
    sort!(:date)
end

# pings_hist_smoothed = @chain pings_hist begin
#     innerjoin(games_played_hist, on = [:date, :name])
#     groupby(:date)
#     @combine(:mean_lr = mean(log.(:Rating)))
#     sort!(:date)
#     @transform :clr = @c accumulate(+, :mean_lr) ./ (1:length(:mean_lr))
# end

# const LATEST_LOG_R = pings_hist_smoothed.clr[end]

# normalized the ratings so that it's the average of the last 365 days
# latest_date = maximum(pings_hist.date)
# pings_for_md2 = @chain pings_for_md1 begin
#     leftjoin(pings_hist_smoothed, on = [:date])
#     @transform :Rating = round(Int, exp(log(:Rating) - :mean_lr + LATEST_LOG_R))
#     sort!(:Rating)
# end

pings_for_md_tmp = select(
    pings_for_md1,
    :Rank,
    :eng_name => "Name",
    :Rating,
    :rating_uncertainty => Symbol("Uncertainty"),
    :n => "Games Played",
    :name => "Hanzi (汉字) Name")

below_threshold_pings_for_md = @chain pings_for_md_tmp begin
    @subset $"Games Played" < NGAME_THRESHOLD
    sort!(:Rating, rev = true)
    @transform :Rank = @c 1:length(:Rating)
end

pings_for_md = @chain pings_for_md_tmp begin
    @subset $"Games Played" >= NGAME_THRESHOLD
    sort!(:Rating, rev = true)
    @transform :Rank = @c 1:length(:Rating)
end

JDF.save("pings_for_md.jdf", pings_for_md)
JDF.save("below_threshold_pings_for_md.jdf", below_threshold_pings_for_md)

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


