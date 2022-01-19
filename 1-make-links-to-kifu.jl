const PATH = "c:/git/baduk-go-weiqi-ratings/"
using Pkg;
Pkg.activate(PATH);
cd(PATH);
using Revise: includet
using DataFrames, DataFrameMacros#, DataFramesMeta
using Chain: @chain
using Dates: Date, Day
using JDF
using Missings: skipmissings
using Revise: includet

includet("utils.jl")

do_for_all = false
## Need to selectively up date this
# function update_player_games_jdf(; do_for_all = false)
df = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
    JDF.load()
    DataFrame()
    @transform :komi_fixed = @c replace(
        :komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )
    @subset :komi_fixed in (6.5, 7.5)
    @transform :date = parse(Date, :date)
    @transform :black = replace(:black, "羋昱廷" => "芈昱廷")
    @transform :white = replace(:white, "羋昱廷" => "芈昱廷")
    @transform :black = coalesce(eng_name(:black), "")
    @transform :white = coalesce(eng_name(:white), "")
    unique
end

df_for_names = @subset(df, @c do_for_all .| (:date .== maximum(:date)))

names_to_update = vcat(df_for_names.black, df_for_names.white) |> unique |> skipmissings |> first |> collect
names_to_update = filter(n -> n != "", names_to_update)

#push!(names_to_update, "Shin Jinseo")

if false
    names_to_update
end

# make the the rating from previous date to see how ratings have moved
if false
    pings_old = CSV.read("records/$(string(date)) pings.csv", DataFrame; select = [:name, :estimate, :std_error])
    pings_old[!, :date] .= date
    return select!(turn_records_into_md(pings_old), :date, :name, :eng_name_old, :Rating, :Rank)
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
end

min_date, max_date = extrema(pings_hist.date)

sjs_ratings_missing_dates = DataFrame(date = [d for d in min_date:Day(1):max_date])

sjs_ratings1 = @chain sjs_ratings begin
    rightjoin(sjs_ratings_missing_dates, on = :date)
    select(:date, :rating)
    sort!(:date)
    @transform :rating = @c begin
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
    rightjoin(sjs_ratings1, on = :date)
    sort!(:date)
    @transform :Rating = @c begin
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

# for each player create the players's page
println("dont forget to turn this off")
names_to_update = @chain pings_hist begin
    @subset @c :date .== maximum(:date)
    sort!(:Rating, rev = true)
    @subset(:eng_name_old != "")
    _[1:100, :eng_name_old]
    vcat(names_to_update)
    unique
end


for name in names_to_update
    if !ismissing(name)
        if name != ""
            ratings_to_merge_on = @chain pings_hist begin
                select(:date, :eng_name_old, :Rating)
                @subset :eng_name_old == name
                select!(Not(:eng_name_old))
                unique(:date)
                leftjoin(sjs_ratings2, on = :date)
                @transform :Rating = :Rating + :rating_adj
                select(Not(:rating_adj))
            end
            #there could be missing ratings

            tmp = @chain df begin
                @subset (:black == name) | (:white == name)
                @transform :Result = ifelse(
                    ((:who_win == "W") & (:white == name)) |
                    ((:who_win == "B") & (:black == name)), "Win", "Lose")
                select!(
                    :date => :Date,
                    :comp => :Comp,
                    :black => :Black,
                    :white => :White,
                    :Result,
                    :result => Symbol("Game result"),
                    :komi_fixed => :Komi
                )
                innerjoin(ratings_to_merge_on, on = :Date => :date)
            end

            if nrow(tmp) == 0
                println("no games for $name so can't create individual game files")
                continue
            end

            tmp = @chain tmp begin
                @subset(!ismissing(:Rating))
                unique([:Date, :Comp, :Black, :White, :Result, Symbol("Game result"), :Komi])
                sort!(:Date, rev = true)
                @transform :Rating_diff = @c vcat(
                    diff(
                        coalesce.(:Rating, 0) |> reverse
                    ) |> reverse,
                    missing)
                rename!(:Rating_diff => Symbol("Diff"))
            end
            JDF.save("./player-games-md/jdf/$name.jdf", tmp)
        end
    end
end
