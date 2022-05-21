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

includet("utils.jl")

# rating offset
const OFFSET = 3800-6.5/log(10)*400

using CSV, Statistics, DataFrames, DataFrameMacros, Chain, Dates

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
end


latest_date = maximum(tbl.date)

# get one year work of the games
tbl_1yr = @chain tbl begin
    @subset (:date < latest_date) && (:date >= latest_date - Dates.Day(364))
    sort!(:date, rev=true)
    @subset :who_win in ("W","B")
end

# extract the names of the players
latest_names = @chain tbl begin
    @subset :date == latest_date
    vcat(_.black, vcat(_.white))
    unique
end

l = length(latest_names)
done = false

while !done
    global latest_names, l, done
    # get more names
    new_names = @chain tbl_1yr begin
        @subset (:white in latest_names) || (:black in latest_names)
        vcat(_.black, _.white)
    end

    latest_names = vcat(latest_names, new_names) |> unique

    newl = length(latest_names)
    if l == newl
        done = true
    else
        l = newl
    end

    println(newl)
end

# obtain only games involving these players
latest_names

tbl_1yr_copy = deepcopy(tbl_1yr)
nplayers = nrow(tbl_1yr_copy)
done = false
while !done
    global done, tbl_1yr_copy, nplayers

    # remove names that has only played one game
    # or remove those that are all wins or all loses
    winners = @chain tbl_1yr_copy begin
        @subset (:white in latest_names) || (:black in latest_names)
        @transform :winner = ifelse(:who_win == "B", :black, :white)
    end

    losers = @chain tbl_1yr_copy begin
        @subset (:white in latest_names) || (:black in latest_names)
        @transform :losers = ifelse(:who_win == "B", :white, :black)
    end

    win_lose_names = intersect(winners.winner, losers.losers)

    # only 4 games missing so it's not really worth it
    tbl_1yr_copy = @chain tbl_1yr_copy begin
        @subset (:white in win_lose_names) && (:black in win_lose_names)
    end

    tmpwl = @chain tbl_1yr_copy begin
        @transform :winner = ifelse(:who_win == "B", :black, :white)
        @transform :loser = ifelse(:who_win == "B", :white, :black)
    end

    morethan2wins = @chain tmpwl begin
        groupby(:winner)
        combine(nrow)
        @subset :nrow >= 2
    end

    morethan2losses = @chain tmpwl begin
        groupby(:loser)
        combine(nrow)
        @subset :nrow >= 2
    end

    tbl_1yr_copy = @chain tbl_1yr_copy begin
        @subset (:white in morethan2wins.winner) && (:black in morethan2losses.loser)
    end

    new_nplayers = nrow(tbl_1yr_copy)
    println(new_nplayers)

    if new_nplayers == nplayers
        done = true
    else
        nplayers = new_nplayers
    end
end


using Flux

names = DataFrame(name = vcat(tbl_1yr_copy.white, tbl_1yr_copy.black)).name |> unique
sort!(names)

idx = sample(1:nrow(tbl_1yr_copy), 4000)

tbl_1yr_copy_train = tbl_1yr_copy[idx, :]
tbl_1yr_copy_test = tbl_1yr_copy[setdiff(1:nrow(tbl_1yr_copy_train), idx), :]

const white_ohe = Flux.onehotbatch(tbl_1yr_copy.white, names)
const black_ohe = Flux.onehotbatch(tbl_1yr_copy.black, names)

const y = Flux.onehotbatch(tbl_1yr_copy.who_win, ("B", "W"))

const white_ohe_test = Flux.onehotbatch(tbl_1yr_copy_test.white, names)
const black_ohe_test = Flux.onehotbatch(tbl_1yr_copy_test.black, names)

const y_test = Flux.onehotbatch(tbl_1yr_copy_test.who_win, ("B", "W"))

HIDDEN_LAYER = 3

embedding = Flux.Chain(
    Dense(length(names), HIDDEN_LAYER, relu),
    # Dropout(0.5),
    SkipConnection(Dense(HIDDEN_LAYER, HIDDEN_LAYER, relu), +),
    # Dropout(0.5),
    SkipConnection(Dense(HIDDEN_LAYER, HIDDEN_LAYER), +)
    # Dense(HIDDEN_LAYER, 2)
)

glm_layer = Flux.Chain(
    SkipConnection(Dense(HIDDEN_LAYER, HIDDEN_LAYER, relu), +),
    # Dropout(0.5),
    SkipConnection(Dense(HIDDEN_LAYER, HIDDEN_LAYER, relu), +),
    # Dropout(0.5),
    Dense(HIDDEN_LAYER, 2)
)

function model(black_ohe, white_ohe)
    # tmp = vcat(embedding(black_ohe), embedding(white_ohe))
    tmp = embedding(black_ohe) - embedding(white_ohe)
    # tmp2 = vcat(tmp, fill(0, (1, size(tmp, 2))))
    glm_layer(tmp)
end

loss(black_ohe, white_ohe, y) = Flux.logitbinarycrossentropy(model(black_ohe, white_ohe), y)

params = Flux.params(embedding)#, glm_layer)

opt = ADAM()

function cb()
    # println("acc test $(mean(tbl_1yr_copy.who_win .== ("B", "W")[Flux.onecold(softmax(model(black_ohe, white_ohe)))])), acc test $(mean(tbl_1yr_copy_test.who_win .== ("B", "W")[Flux.onecold(softmax(model(black_ohe_test, white_ohe_test)))]))")
    println("loss: $(loss(black_ohe, white_ohe, y)) acc $(mean(tbl_1yr_copy.who_win .== ("B", "W")[Flux.onecold(softmax(model(black_ohe, white_ohe)))])))")
end

cb()

@time Flux.train!(loss, params, [(black_ohe, white_ohe, y)], opt; cb = cb) # compilation time

Flux.@epochs 1000 Flux.train!(loss, params, [(black_ohe, white_ohe, y)], opt; cb = Flux.throttle(()->cb(), 10))

#### accuracy
mean(tbl_1yr_copy.who_win .== ("B", "W")[Flux.onecold(softmax(model(black_ohe, white_ohe)))])
# mean(tbl_1yr_copy_test.who_win .== ("B", "W")[Flux.onecold(softmax(model(black_ohe_test, white_ohe_test)))])

#### assess on latestt
tbl_latest = @chain tbl begin
    @subset :date == latest_date
end

sjs_ohe = Flux.onehotbatch(tbl_latest.black, names)
all_ohe = Flux.onehotbatch(tbl_latest.white, names)
softmax(model(sjs_ohe, all_ohe))

tbl_latest[!, :pred] = ["B", "W"][Flux.onecold(softmax(model(sjs_ohe, all_ohe)))]

mean(tbl_latest.who_win .== tbl_latest.pred)

# tmp=DataFrame(names=names, rating = reshape(embedding(Flux.onehotbatch(names, names)), :))
# sort!(tmp, :rating, rev=true)

#### rating
# tmp = DataFrame(names=names, rating = reshape(embedding(Flux.onehotbatch(names, names)), :))

# sort!(tmp, :rating)

### How does Shin Jinseo do?
sjs_ohe = Flux.onehotbatch(["申眞諝" for _ in 1:length(names)], names)
all_ohe = Flux.onehotbatch(names, names)

tmp = DataFrame(
    names = names,
    black_win = reshape(softmax(model(sjs_ohe, all_ohe))[1:1, :], :),
    white_win = reshape(softmax(model(all_ohe, sjs_ohe))[2:2, :], :)
)

@chain tmp begin
    @transform :rating = (:black_win + :white_win) / 2
    leftjoin(select(tmp2, [:name, :nrow]), on =:names=>:name)
    sort!(:rating)
    @subset !ismissing(:nrow)
end

function calcprob(name1, name2)
    tmp1 = softmax(model(Flux.onehotbatch([name1], names), Flux.onehotbatch([name2], names)))[1,1]
    tmp2 = softmax(model(Flux.onehotbatch([name2], names), Flux.onehotbatch([name1], names)))[2,1]
    tmp1, tmp2, (tmp1+tmp2)/2
end

calcprob("申眞諝", "楊鼎新")


#### pca
names = sort(names)

xy = embedding(Flux.onehotbatch(names, names))
df = DataFrame(xy |> transpose, :auto)

using RCall
@rput df

R"""
pr = prcomp(df)
ok = pr$rotation
pr
"""

@rget ok
firstpc=transpose(xy)*ok[:, 1:1]
secondpc=transpose(xy)*ok[:, 2:2]
thirdpc=transpose(xy)*ok[:, 3:3]
df[!, :rating1] = reshape(firstpc, :)
df[!, :rating2] = reshape(secondpc, :)
df[!, :rating3] = reshape(thirdpc, :)
df[!, :name] = copy(names)

df[!, :rating] = df[!, :rating1] + df[!, :rating2]

tmp = sort(select(df, [:name, :rating]), :rating)

tmp2 = @chain DataFrame(name = vcat(tbl_1yr_copy.black, tbl_1yr_copy.white)) begin
    groupby(:name)
    combine(nrow)
    rightjoin(tmp, on =:name)
    sort!(:rating)
    @subset :nrow > 10
end


function stre(name)
    embedding(Flux.onehotbatch([name], names))
end

stre("申眞諝")
stre("柯潔")

filter(name->get(NAMESDB, name, "") == "Zhao Chenyu", names)

softmax(model(Flux.onehotbatch(["朴廷桓"], names), Flux.onehotbatch(["趙晨宇"], names)))
softmax(model(Flux.onehotbatch(["趙晨宇"], names), Flux.onehotbatch(["朴廷桓"], names)))


# rest
sjs_ohe = Flux.onehotbatch(tbl_1yr_copy.black, names)
all_ohe = Flux.onehotbatch(tbl_1yr_copy.white, names)

sort!(DataFrame(name=names, rating = reshape(xy, :)), :rating, rev=true)

filter(name->get(NAMESDB, name, "") == "Shin Jinseo", names)
filter(name->get(NAMESDB, name, "") == "Ke Jie", names)
filter(name->get(NAMESDB, name, "") == "Park Junghwan", names)
filter(name->get(NAMESDB, name, "") == "Xie Ke", names)
filter(name->get(NAMESDB, name, "") == "Tang Weixing", names)

sjs_ohe = Flux.onehotbatch(["申眞諝"], names)
kj_ohe = Flux.onehotbatch(["柯潔"], names)
pjh_ohe = Flux.onehotbatch(["朴廷桓"], names)
xk_ohe = Flux.onehotbatch(["謝科"], names)
twx_ohe = Flux.onehotbatch(["唐韋星"], names)

softmax(model(sjs_ohe, kj_ohe))
softmax(model(kj_ohe, sjs_ohe))

softmax(model(sjs_ohe, pjh_ohe))
softmax(model(pjh_ohe, sjs_ohe))

softmax(model(kj_ohe, pjh_ohe))
softmax(model(pjh_ohe, kj_ohe))

softmax(model(sjs_ohe, xk_ohe))
softmax(model(xk_ohe, sjs_ohe))

softmax(model(sjs_ohe, xk_ohe))
softmax(model(xk_ohe, sjs_ohe))

softmax(model(sjs_ohe, twx_ohe))
softmax(model(twx_ohe, sjs_ohe))

softmax(model(kj_ohe, xk_ohe))
softmax(model(xk_ohe, kj_ohe))

xy = embedding(Flux.onehotbatch(names, names))

embedding(sjs_ohe) - embedding(kj_ohe)

embedding(kj_ohe) - embedding(sjs_ohe)

using Plots

names1 = [ifelse(name in ["申眞諝", "柯潔", "朴廷桓", "謝科", "唐韋星"], get(NAMESDB, name, ""), "") for name in names]

plot(
    xy[1, :], xy[2, :], seriestype=:scatter,
    series_annotations = text.(names1, :bottom))

names_eng = filter(!=(""), [get(NAMESDB, name, "") for name in names])

df = DataFrame(transpose(embedding(all_ohe)) |> collect, :auto)

plot(df.x1, df.x2, seriestype=:scatter)

sort!(df, :x1, rev=true)
plot!(df.x1, -0.01587 .+ -0.23938 .* df.x1)

using GLM
lm(@formula(x2~x1), df)

using RCall
@rput df

R"""
lm(x2~x1, df)
prcomp(df)
"""

sort!(DataFrame(name = names, sjs_win = sjs_win), :sjs_win)


sjs_ohe = Flux.onehotbatch(["村川大介" for _ in 1:length(names)], names)
all_ohe = Flux.onehotbatch(names, names)

sjs_win = softmax(model(sjs_ohe, all_ohe))[1, :]

sort!(DataFrame(name = names, sjs_win = sjs_win), :sjs_win)


softmax(model(sjs_ohe, all_ohe))[1, :]

embedding(sjs_ohe)
embedding(all_ohe)


names[findall(<(0.8), softmax(model(sjs_ohe, all_ohe))[1, :])]


name1, name2 = "Numadate Sakiya", "Ichiriki Ryo"
function calc_prob(name1, name2)
    # print(name1, name2)
    name3 = filter(name->get(NAMESDB, name, "") == name1, names) |> unique
    name4 = filter(name->get(NAMESDB, name, "") == name2, names) |> unique

    ohe1 = Flux.onehotbatch(name3[1:1], names)
    ohe2 = Flux.onehotbatch(name4[1:1], names)

    softmax(model(ohe1, ohe2))[1]
end


[calc_prob(name1, name2) for (name1, name2) in Iterators.product(names_eng, names_eng)]

collect(Iterators.product(names_eng, names_eng))



embedding(white_ohe)s

embedding(sjs_ohe)
embedding(kj_ohe)
embedding(pjh_ohe)
embedding(xk_ohe)


model(sjs_ohe, xk)

loss(black_ohe, white_ohe)

