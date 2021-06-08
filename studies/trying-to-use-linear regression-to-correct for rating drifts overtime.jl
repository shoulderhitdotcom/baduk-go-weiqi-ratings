using DataFrames, Chain, DataFramesMeta, CSV, FloatingTableView, StatsBase, Statistics, JDF
using Dates: Date

# load the gamesdb
gamesdb = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
    JDF.load()
    DataFrame()
    @transform date = parse.(Date, :date)
    @transform komi_fixed = replace(
        :komi,
        6.4 => 6.5,
        8.0 => 7.5,
        750 => 7.5,
        605.0 => 6.5
    )
    @where in.(:komi_fixed, Ref((6.5, 7.5)))
    select!(Not([:sgf, :comp, :result, :kifu_link, :win_by, :komi]))
end

paths = readdir("records", join=true)

if false
    nrows = map(path->CSV.read(path, DataFrame) |> nrow, paths)
    browse(DataFrame(nrows=nrows))
end

# paths = readdir("records", join=true)

# function meh(paths)
#     # note: from 27 seems ok
#     res = DataFrame[]
#     for upto = 1:length(paths)
#         df = CSV.read(paths[upto], DataFrame)
#         df[!, :date] .= Date(paths[upto][9:18])
#         push!(res, select!(df, :name, :date))
#     end
#     res
# end

# @time aa = meh(paths)

# aa = reduce(vcat, aa)

# ok = split.(aa.name, '_')

# pos= findall(length.(ok) .== 2)

# aa[pos, :].date |> unique


function get_corrected_estimate(paths)
    # note: from 27 seems ok
    upto=488

    df = CSV.read(paths[upto], DataFrame)
    df[!, :date] .= Date(paths[upto][9:18])
    df[!, :estimate_corrected] = df.estimate

    fnl_res = [select(df, Not(:term))]

    upto+=1
    while upto <= length(paths)
        df_next = CSV.read(paths[upto], DataFrame)
        # find out who played a game on this date
        game_date = Date(paths[upto][9:18])
        # println(game_date)

        games_played_on_date = @where(gamesdb, :date .== game_date)

        players_who_played = unique(vcat(games_played_on_date.white, games_played_on_date.black))

        # fit a linear model on players who didn't play to try and keep their ratigs the same
        data_for_lm = @chain df_next begin
            _[1:100, :] # use only the top 100 players
            @where .!in.(:name, Ref(players_who_played))
            select(:name, :estimate=>:estimate_next)
            innerjoin(select(df, :name, :estimate_corrected), on=:name)
        end

        m = ones(nrow(data_for_lm), 2)
        m[:, 2] .= data_for_lm.estimate_next

        intercept, slope = m\data_for_lm.estimate_corrected

        # if game_date == Date(2005, 08, 05)
        #     return df_next
        #     # intercept = 0.0
        #     # slope = 1.0
        # end


        df_next[!, :estimate_corrected] = intercept .+ slope.*df_next.estimate
        df_next[!, :date] .= game_date
        push!(fnl_res, select(df_next, Not(:term)))

        df = df_next
        upto+=1
    end
    fnl_res
end

@time fnl_res = get_corrected_estimate(paths);

fnl_res2 = reduce(vcat,fnl_res)

fnl_res3=@chain fnl_res2 begin
    @where :Rank .== 1
    select(:name, :estimate, :estimate_corrected, :date)
    unique()
end

browse(fnl_res3)

JDF.save("fnl_res.jdf", fnl_res2)

fnl_res2 = JDF.load("fnl_res.jdf") |> DataFrame


