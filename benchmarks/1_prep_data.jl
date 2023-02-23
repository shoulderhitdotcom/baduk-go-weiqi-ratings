## Conclusion
### The CUDA one is quite fast but rcall works well enough, so no need to do anything
###

const BENCHMARK_PATH = "c:/git/baduk-go-weiqi-ratings/benchmarks/"
using Pkg; Pkg.activate(BENCHMARK_PATH); cd(BENCHMARK_PATH)
using DataFrames
# Pkg.add("CUDA")

includet("../utils.jl")

using CUDA
CUDA.allowscalar(false)

tbl = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
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

mad = maximum(tbl.date)
df, tbl_1yr, games_played, _ = prep_data(mad-Day(364), mad, tbl);

#########################################
# glm
########################################
CSV.write("tmp-df-pls-del.csv", df)

@time R"""
    df = data.table::fread("tmp-df-pls-del.csv")
    #m = glm(y~.-1, df, family=binomial, start = rep(5, ncol(df)-1))
    m = glm(y~.-1, df, family=binomial)
    strengths = broom::tidy(m)
"""

rm("tmp-df-pls-del.csv")

#########################################
# CUDA
########################################

# names = sort!(reduce(vcat, unique.([df.black, df.white])) |> unique)

games = Matrix(df[:, r"x"])

games = games[:, 1:end-2] |> cu

results = df[:, r"y"] |> Matrix |> cu

using Flux

using Flux.Losses: logitbinarycrossentropy

function loss(games, results)
    x = games*strengths
    logitbinarycrossentropy(x, results)
end


strengths = zeros(Float32, ncol(df)-3) |> cu
opt = RADAM()

# testing
loss(games, results)
CUDA.@time Flux.train!(loss, params(strengths), [(games, results)], opt)

function train!(strengths, games, results, opt; maxit=18_888)
    last_loss = loss(games, results)

    for i in 1:maxit
        # every 100 epochs try to asses fit
        if mod(i, 100) == 0
            new_loss = loss(games, results)
            if abs(last_loss - new_loss) < eps(Float32)
                println("$i iterations ran")
                return strengths
            else
                last_loss = new_loss
            end
        end

        # train one epoch
        Flux.train!(loss, params(strengths), [(games, results)], opt)
    end

    println("Ran out of iterations")
    strengths
end


CUDA.@time ping = train!(strengths, games, results, opt);

using Chain, DataFramesMeta

players = @chain tbl_1yr begin
    @where :date .<= mad
    @where :date .>= mad - Day(365*2-1)
    vcat(_.black, _.white)
    unique
    sort!
end

df1 = @chain begin
    DataFrame(players = players, ping = strengths |> cpu)
    leftjoin(games_played, on =:players=>:name)
    @transform std = std(:ping) ./ :n
    @transform ping_for_ranking = :ping .- 1.97 .* :std
    sort!(:ping_for_ranking, rev=true)
end


using Statistics



