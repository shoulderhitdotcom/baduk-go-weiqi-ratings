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
using TableScraper: scrape_tables

includet("utils.jl")

# the threshold below which will see the player excluded from the main list
const NGAME_THRESHOLD = 13

# the intended syntax
# @target = tbl = @chain @watch_path "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
tbl = @chain joinpath(WSPATH, "kifu-depot-games-with-sgf.jdf/") begin
    JDF.load()
    DataFrame()
    @transform :date = parse(Date, :date)
    @transform :komi_fixed = @bycol replace(
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
    sort!(:date)
end

# 羋昱廷

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
    for date_filter in filter(x -> x <= Date("2021-09-01"), sort!(unique(tbl.date), rev=true))
        println(date_filter)
        tbl_earlier = @subset(tbl, :date <= date_filter)
        @time estimate_ratings_and_save_records(tbl_earlier)
    end
end

@time pings, games, white75_advantage, black65_advantage, abnormal_players, from_date, to_date =
    estimate_ratings_and_save_records(tbl);

# compute rank tiers
# can I switch the ranks of two players if I just

# function meh(ok)
#     m = zeros(Int, length(players_involved), length(players_involved))
#     for row in eachrow(ok)
#         m[row.bindex, row.windex] = 1
#         m[row.windex, row.bindex] = 1
#     end
#     for i in 1:length(players_involved)
#         m[i, i] = 1
#     end

#     last_m = deepcopy(m)
#     while true
#         # println("ok")
#         # println(sum(last_m))
#         next_m = min.(last_m * m, 1)
#         # println(sum(next_m))
#         if next_m == last_m
#             return last_m
#         end
#         last_m = next_m
#     end
# end

# const TO_DATE = maximum(tbl.date)
# const FROM_DATE = TO_DATE - Day(364)


# const ELIGIBLE_PINGS = @chain pings begin
#     @subset :n > NGAME_THRESHOLD
#     sort!(:estimate, rev = true)
# end

# # multipl unitl now differ
# const TBL_1YR = @chain tbl begin
#     @subset :date >= FROM_DATE
# end

# const PLAYERS_INVOLVED = @chain TBL_1YR begin
#     # @subset :white in nwb || :black in nwb
#     stack([:black, :white])
#     _.value
#     unique()
#     sort()
# end


# function compute_rank_tiers(first_rank)
#     eligible_pings = @chain ELIGIBLE_PINGS begin
#         _[first_rank:first_rank+1, :]
#         DataFrame(black = _.name[1], white = _.name[2], date = maximum(tbl.date), komi_fixed = 6.5, who_win = "W")
#     end

#     players_involved = @chain TBL_1YR begin

#         stack([:black, :white])
#         _.value
#         unique()
#         sort()
#     end

#     m = @chain TBL_1YR begin
#         @transform :windex = @bycol indexin(:white, players_involved)
#         @transform :bindex = @bycol indexin(:black, players_involved)
#         @transform :dummy = 1
#         meh()
#     end

#     players_involved1 = players_involved[m[1, :].==1]

#     tbl_eligible = @chain TBL_1YR begin
#         @subset :white in players_involved1 || :black in players_involved1
#         vcat(eligible_pings)
#     end

#     pings_tier, _ = estimate_ratings_and_save_records(tbl_eligible)

#     pings_tier
# end

# @time compute_rank_tiers(2)

# abc = estimate_ratings_and_save_records(tbl)
# using GLM
# df
# names(df)
# f = Term(:y) ~ sum(Term(Symbol("x$i")) for i in 1:550)
# glm(f, df, Binomial())

# @target should allow the return of a path where things are stored
# out_path = @target pings_for_md1 = @chain @watch(pings) begin

# download the ratings from goratings and do a regression

goratings_latest = scrape_tables("https://goratings.org/en")[2] |> DataFrame

goratings_latest = @chain goratings_latest begin
    @transform :elo = parse(Int, :Elo)
    select(:Name, :elo)
end

# the 99th percentile value in Normal(0, 1)
# used to discount
const P99 = 2.326348

pings_for_alignment = @chain pings begin
    @transform :eng_name = get(NAMESDB, :name, "")
    @subset :eng_name != ""
    innerjoin(goratings_latest, on=:eng_name => :Name)
    @transform :diff = :elo - (:estimate - P99 * :std_error) * 400 / log(10)
    sort!(:elo, rev=true)
    select(:eng_name, :elo, :diff)
    _[1, :] # get the difference between number 1 player according to goratings
end

function turn_records_into_md(pings)
    @chain pings begin
        @transform :name = @bycol Vector{String}(:name) # avoid weird SentinelArray Bug
        @transform :eng_name_old = coalesce(eng_name(:name), "")
        @transform :eng_name = "[" * :eng_name_old * "](./player-games-md/md/" * :eng_name_old * ".md)"
        @transform :estimate_for_ranking = :estimate - P99 * :std_error
        # @transform :Rating = round(Int, :estimate * 400 / log(10) + OFFSET)
        # @transform :rating_for_ranking = round(Int, :estimate_for_ranking * 400 / log(10) + OFFSET)
        # @transform :rating_uncertainty = "±" * string(round(Int, :std_error * 400 / log(10)))
        @transform :Rating = round(Int, :estimate_for_ranking * 400 / log(10) + pings_for_alignment.diff)
        @transform :rating_uncertainty = "±" * string(round(Int, :std_error * 400 / log(10)))
        sort!(:Rating, rev=true)
        # @transform :Rank = @bycol 1:length(:Rating)
    end
end

# make ratings database
if false# run only once to generate the historical ratings
    @time pings_hist = mapreduce(vcat, Date(2020, 1, 1):Day(1):Date(2022, 5, 5)) do date
        println(date)
        # @time pings_hist = mapreduce(vcat, missing_dates) do date
        if isfile("records/$(string(date)) pings.csv")
            pings_old = CSV.read("records/$(string(date)) pings.csv", DataFrame; select=[:name, :estimate, :std_error])
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

using Dates

ngames = @chain tbl begin
    @subset :date >= today() - Day(365)
    stack([:black, :white], :date)
    groupby(:value)
    combine(nrow)
    @transform :eng_name_old = get(NAMESDB, :value, "")
end
# figure out how's the best

md = maximum(pings_hist.date)

top100_names = @chain pings_hist begin
    @subset :date == md
    @subset(:eng_name_old != "")
    sort(:Rating, rev=true)
    _[1:100, :eng_name_old]
end

biggest_rating_jump = @chain pings_hist begin
    @subset :eng_name_old in top100_names
    groupby(:eng_name_old)
    combine(df -> begin
        if nrow(df) > 1
            tmp = sort(df, :date)[end-1:end, :]
            return DataFrame(date=tmp[end, :date], rate_diff=tmp[end, :Rating] - tmp[end-1, :Rating])
        else
            return DataFrame()
        end
    end)
    @subset :date == md
    innerjoin(ngames, on=:eng_name_old)
    select(Not(:value))
    @subset :nrow >= NGAME_THRESHOLD
    @subset :rate_diff != 0
    @subset :date >= today() - Day(14)
    @transform :abs_rate_diff = abs(:rate_diff)
    sort(:rate_diff, rev=true)
    vcat(_[1:10, :],
        _[end-9:end, :])
end

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
                @transform :n = @bycol ma365(:n)
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
#     @transform :clr = @bycol accumulate(+, :mean_lr) ./ (1:length(:mean_lr))
# end

# const LATEST_LOG_R = pings_hist_smoothed.clr[end]

# normalized the ratings so that it's the average of the last 365 days
# latest_date = maximum(pings_hist.date)
# pings_for_md2 = @chain pings_for_md1 begin
#     leftjoin(pings_hist_smoothed, on = [:date])
#     @transform :Rating = round(Int, exp(log(:Rating) - :mean_lr + LATEST_LOG_R))
#     sort!(:Rating)
# end

# Do a test to see if successive should be grouped together
# latest_rating = @chain readdir("records/"; join = true) begin
#     partialsort!(1, rev = true)
#     CSV.read(DataFrame)
# end

# diff(latest_rating.estimate)

# sqrt.(latest_rating.std_error[1:end-1] .^ 2 .+ latest_rating.std_error[2:end] .^ 2)

# determine rank ranges
rank_ranges = @chain pings_hist begin
    @subset @bycol maximum(:date) - Day(364) .<= :date
    @aside counts = @chain tbl begin
        @subset @bycol maximum(:date) - Day(364) .<= :date
        stack([:black, :white])
        groupby(:value)
        combine(nrow => :ngames)
    end
    leftjoin(counts, on=:name => :value)
    @subset !ismissing(:ngames)
    # @subset :ngames >= NGAME_THRESHOLD
    groupby(:date)
    combine(df -> begin
        df = sort(df, :Rating, rev=true)
        df[!, :ranking] = 1:nrow(df)
        df
    end)
    groupby(:name)
    @combine(:form_range = string(extrema(:ranking)), :median_rank = median(:ranking))
end




# figure out the adjustment needed for each day
sjs_ratings = scrape_tables("https://www.goratings.org/en/players/1313.html")[2] |> DataFrame

sjs_ratings = @chain sjs_ratings begin
    select(:Date, :Rating)
    @transform begin
        :rating = parse(Int, :Rating)
        :date = Date(:Date)
    end
    sort!(:Date)
    unique(:Date) # because a player can play two games in one day
end

min_date, max_date = extrema(pings_hist.date)

sjs_ratings_missing_dates = DataFrame(date=[d for d in min_date:Day(1):max_date])

sjs_ratings1 = @chain sjs_ratings begin
    rightjoin(sjs_ratings_missing_dates, on=:date)
    select(:date, :rating)
    sort!(:date)
    @transform :rating = @bycol begin
        tmp = copy(:rating)
        for i in 2:length(tmp)
            if tmp[i] |> ismissing
                tmp[i] = tmp[i-1]
            end
        end
        tmp
    end
    @subset(!ismissing(:rating))
end

sjs_ratings2 = @chain pings_hist begin
    select(:date, :eng_name_old, :Rating)
    @subset :eng_name_old == "Shin Jinseo"
    select!(Not(:eng_name_old))
    unique(:date)
    rightjoin(sjs_ratings1, on=:date)
    sort!(:date)
    @transform :Rating = @bycol begin
        tmp = copy(:Rating)
        for i in 2:length(tmp)
            if tmp[i] |> ismissing
                tmp[i] = tmp[i-1]
            end
        end
        tmp
    end
    @transform :rating_adj = :rating - :Rating
    select(:date, :rating_adj)
end

# adjust the whole history ratings
pings_hist_adj = @chain pings_hist begin
    innerjoin(sjs_ratings2, on=:date)
    @subset !ismissing(:rating_adj)
    @transform :Rating_mine = :Rating
    @transform! :Rating = :Rating + :rating_adj
end

# determine biggest movers
# md = maximum(pings_hist_adj.date)
top100names = @chain pings_hist_adj begin
    @subset :date == md
    sort(:Rating, rev=true)
    _[1:100, :name]
end


d2, d1 = partialsort(pings_hist_adj.date |> unique, 1:2, rev=true)

top100_movements = @chain pings_hist_adj begin
    @subset :name in top100names
    @subset :date in (d1, d2)
    groupby(:name)
    combine(df -> begin
        if nrow(df) == 1
            # error("what")
            return DataFrame(rating_change = missing)
            # DataFrame(rating_change=diff(_.Rating))
        end
        @chain df begin
            sort(:date)
            DataFrame(rating_change=diff(_.Rating))
        end
    end)
    # @subset :rating_change != 0
    # @transform :abs_rating_change = abs(:rating_change)
    # sort(:abs_rating_change, rev=true)
    # @transform :eng_name = get(NAMESDB, :name, "")
    # select(:eng_name => :Name, :abs_rating_change => Symbol("Rating Change"), :name => Symbol("汉字"))
end

JDF.save("top100_movements.jdf", top100_movements)


# compute the average rating
mean_ratings = @chain pings_hist_adj begin
    @subset today() - Day(364) <= :date
    groupby(:name)
    @combine(:mean_rating = mean(:Rating))
end

function meh(days)
    mean_ratings = @chain pings_hist_adj begin
        @subset today() - Day(days) <= :date
        groupby([:name, :eng_name_old])
        @combine(:mean_rating = mean(:Rating))
        sort(:mean_rating, rev=true)
        @transform :rank = @bycol 1:length(:mean_rating)
        @subset :eng_name_old in ("Ke Jie", "Weon Seongjin")
        # _[2:2, :eng_name_old]
    end

    kj_rating = @chain mean_ratings begin
        @subset :eng_name_old == "Ke Jie"
        _[1, :rank]
    end

    wsj_rating = @chain mean_ratings begin
        @subset :eng_name_old != "Ke Jie"
        _[1, :rank]
    end

    kj_rating, wsj_rating
end

# using BadukGoWeiqiTools: create_player_info_tbl
# players_info = create_player_info_tbl()

# countmap(players_info.affiliation)

# pings_for_md2 = @chain pings_for_md1 begin
#     leftjoin(players_info, on=:eng_name_old => :name)
#     @transform :date_of_birth = @passmissing Date(:date_of_birth)
#     @transform :age = @passmissing round(getproperty(today() - :date_of_birth, Symbol("value")) / 365, digits=1)
#     sort(:Rating, rev=true)
#     @transform :age = @passmissing :age > 2000 ? missing : :age
#     @transform :region = @passmissing ifelse(:affiliation in ("Nihon Kiin", "Kansai Kiin"), "JPN", :nationality)
#     @transform :region = @passmissing ifelse(:affiliation == "Hanguk Kiwon", "KOR", :nationality)
#     @transform :region = @passmissing ifelse(:affiliation == "Taiwan Go Association", "TWN", :nationality)
# end


# ready for output
pings_for_md_tmp = select(
    pings_for_md1,
    :Rank,
    # :age,
    # :sex,
    # :region,
    :eng_name => "Name",
    :Rating,
    :n => "Games Played",
    :n,
    :name => "Hanzi (汉字) Name")

below_threshold_pings_for_md = @chain pings_for_md_tmp begin
    @subset :n < NGAME_THRESHOLD
    sort!(:Rating, rev=true)
    @transform :Rank = @bycol 1:length(:Rating)
    select(Not(:n))
end

pings_for_md = @chain pings_for_md_tmp begin
    @subset :n >= NGAME_THRESHOLD
    sort!(:Rating, rev=true)
    @transform :Rank = @bycol 1:length(:Rating)
    select(Not(:n))
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
