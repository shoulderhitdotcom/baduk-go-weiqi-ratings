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
using TableScraper: scrape_tables
using GLM # need to estimate trends

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

names_to_update = @chain vcat(df_for_names.black, df_for_names.white) begin
    unique
    skipmissings
    first
    collect
    filter(n -> n != "", _)
end

# @warn ("remove this")
# if false
#     md = maximum(pings_hist.date)
#     names_to_update = @chain pings_hist begin
#         @subset :date == md
#         sort(:Rating, rev = true)
#         _[1:100, :eng_name_old]
#         vcat(names_to_update, _)
#         unique
#     end
# end

# make the the rating from previous date to see how ratings have moved
if false
    pings_old = CSV.read("records/$(string(date)) pings.csv", DataFrame; select = [:name, :estimate, :std_error])
    pings_old[!, :date] .= date
    return select!(turn_records_into_md(pings_old), :date, :name, :eng_name_old, :Rating, :Rank)
end



# for each player create the players's page
# println("dont forget to turn this off")
# names_to_update = @chain pings_hist begin
#     @subset @c :date .== maximum(:date)
#     sort!(:Rating, rev = true)
#     @subset(:eng_name_old != "")
#     _[1:100, :eng_name_old]
#     vcat(names_to_update)
#     unique
# end

# Biggest movers
ngames_last_year = @chain tbl begin
    @subset max_date - Day(364) <= :date
    select(:date, :black, :white)
    stack([:black, :white], :date)
    groupby(:value)
    combine(nrow => :ngames)
end

latest_ratings = @chain pings_hist_adj begin
    @subset :date == max_date
    leftjoin(ngames_last_year, on = :name => :value)
    @subset !ismissing(:ngames)
    @subset :ngames >= NGAME_THRESHOLD
    sort!(:Rating, rev = true)
    _[1:100, :]
    select(:name)
end

day_range_days = [7, 30, 90, 180, 365]
biggest_movers = []
for d in day_range_days
    start_date = max_date - Day(d - 1)

    tmp = @chain pings_hist_adj begin
        @subset :date >= start_date
        groupby([:name, :eng_name_old])
        combine(df -> begin
                df = sort(df, :date)
                DataFrame(
                    drop = df.Rating[end] - maximum(df.Rating),
                    rise = df.Rating[end] - minimum(df.Rating)
                )
                df.x = [x.value for x in (df.date .- minimum(df.date))]
                model = lm(@formula(Rating ~ x), df)
                coef(model)[2]
            end, nrow)
        @subset @c :nrow .== maximum(:nrow)
        # @transform :x2 = ifelse(abs(:drop) > abs(:rise), :drop, :rise)
        # @transform :x1 = :rise + :drop
        leftjoin(ngames_last_year, on = :name => :value)
        @subset !ismissing(:ngames)
        @subset :ngames >= NGAME_THRESHOLD
        # sort!(:x1, by = x -> abs(x), rev = true)
        innerjoin(latest_ratings, on = :name)
        # @subset :x1 > 0
        sort!(:x1, rev = true)
    end

    push!(biggest_movers, tmp)
end

biggest_movers[end]
JDF.save("biggest_movers.jdf", biggest_movers[end])

pings_hist_adj



# update the player ratings page
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
                sort(:date)
            end
            #there could be missing ratings

            function locf!(val)
                last_val = val[1]
                for i in 2:length(val)
                    if ismissing(val[i])
                        val[i] = last_val
                    else
                        last_val = val[i]
                    end
                end
                val
            end

            locf(val) = locf!(copy(val))

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
                leftjoin(ratings_to_merge_on, on = :Date => :date)
                sort(:Date)
                @transform :Rating = @c locf(:Rating)
            end

            if nrow(tmp) == 0
                println("no games for $name so can't create individual game files")
                continue
            end
            # println(name)

            # skip
            all(ismissing.(tmp.Rating)) && continue

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
