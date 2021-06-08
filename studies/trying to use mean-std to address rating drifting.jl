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

function get_mean_std(paths)
    # note: from 27 seems ok
    upto=488
    # upto=1

    fnl_res = DataFrame[]

    while upto <= length(paths)
        df = CSV.read(paths[upto], DataFrame)
        df[!, :date] .= Date(paths[upto][9:18])
        df[!, :estimate_corrected] = (df.estimate .- mean(df.estimate)) ./ std(df.estimate)
        push!(fnl_res, select(df, Not(:term)))
        upto += 1
    end
    fnl_res
end

@time fnl_res = get_mean_std(paths);

fnl_res2 = reduce(vcat,fnl_res)

fnl_res3=@chain fnl_res2 begin
    @where :Rank .== 1
    select(:name, :estimate, :estimate_corrected, :date)
    unique()
end

browse(fnl_res3)

using StatsPlots

@df fnl_res3 plot(:Date, :estimate_corrected)


JDF.save("fnl_res.jdf", fnl_res2)

fnl_res2 = JDF.load("fnl_res.jdf") |> DataFrame


