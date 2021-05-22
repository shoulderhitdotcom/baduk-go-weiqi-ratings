
includet("namesdb.jl")

NAMESDB = deserialize("namesdb")

# NAMESDB = create_names_db(NAME_DB_JSON; force=true)

function eng_name(name)
    try
        NAMESDB[name]
    catch _
        return missing
    end
end

@time pings_kj_form, games, white75_advantage, black65_advantage= estimate_rating(mad-Day(364), mad);

# @time pings, games = estimate_rating(mad-Day(364)-Day(30), mad-Day(30));

@time ok, _ = estimate_rating(Date(2020,1,1), Date(2020,12,31));ok

const OFFSET = 3800-10/log(10)*400
pings_for_md = @chain pings begin
   @where :n .> 10
   @transform eng_name = coalesce.(eng_name.(:name), Ref(""));
   @transform Rating = @. round(Int, :ping * 400 / log(10) + OFFSET)
   @transform Rank = 1:length(:ping)
   select!(:Rank, :eng_name=>"Name", :Rating, :n=>"Games Played", :name=>"Hanzi (汉字) Name", :ping => "Ping (品）*")
end

# white75_advantage*400/log(10)
# black65_advantage*400/log(10)

println("Rating Based on $(nrow(games)) from $(mad-Day(364)) to $mad")
println("* Ping is a reference to ancient Chinese Weiqi gradings"); println()

includet("c:/weiqi/simulation/utils.jl")
df_to_md(pings_for_md)

d = Date("2018-12-31")

@time estimate_rating(Date(2019,1,1), Date(2019,12,31))
@time estimate_rating(Date(2018,1,1), Date(2018,12,31))
@time estimate_rating(Date(2017,1,1), Date(2017,12,31))
@time estimate_rating(Date(2016,1,1), Date(2016,12,31))
@time estimate_rating(Date(2015,1,1), Date(2015,12,31))
@time estimate_rating(Date(2014,1,1), Date(2014,12,31))
@time estimate_rating(Date(2010,1,1), Date(2010,12,31))




from_date = Date(2020,1,1)

function winpct(ping1, ping2)
    x = (ping1 - ping2)
    1/(1+exp(-x))
end

using FloatingTableView
pings1 = @where(pings, :n .> 7)
browse(pings)
browse(pings1)

using Clustering
km = kmeans(reshape(pings.ping, 1, :), 2)

mean(pings.ping[km.assignments .== 1])

pings[!, :cluster] = km.assignments

browse(pings)

NAMESDB = create_names_db(NAME_DB_JSON; force=true)

function eng_name(name)
    try
        NAMESDB[name]
    catch _
        return missing
    end
end

pings = @transform pings eng_name = eng_name.(:name)

using Statistics
mean(pings.ping)
std(pings.ping)

@chain tbl_1yr begin
    @where (:black .== "王立誠") .| (:white .== "王立誠")
end
# using DataFrames

# df = DataFrame(winner = rand(1:800, 4000), loser = rand(1:799, 4000))

# # make sure they are different
# df.loser = ifelse.(df.winner .== df.loser, df.loser .+ 1, df.loser)

# using Optim: optimize, BFGS

# init_w = rand(800)

# function prob_win(strength1, strength2)
#     x = (strength1 - strength2)
#     1/(1+exp(-x))
# end

# const winner_ids = df.winner
# const loser_ids = df.loser

# function neg_log_lik(init_w)
#     -sum(log.(prob_win.(init_w[P1], init_w[P2])))
# end

# @time opm = optimize(neg_log_lik, init_w, BFGS())


