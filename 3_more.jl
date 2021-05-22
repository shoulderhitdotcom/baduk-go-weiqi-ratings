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
