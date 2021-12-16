using TableScraper
using DataFrames, DataFrameMacros, Chain, Dates, JDF

# tbl = scrape_tables("https://www.goratings.org/en/", identity)[2] |> DataFrame

# a = tbl.Name[1][1]


# function get_rating(a)
#     name = string(a.children[1])
#     url = "http://www.goratings.org" * a.attributes["href"][3:end]
#     b = scrape_tables(url)[2] |> DataFrame
#     @chain b begin
#         @transform begin
#             :Rating = parse(Int, :Rating)
#             :Date = Dates.Date(:Date)
#         end
#         select([:Date, :Rating])
#         unique([:Date, :Rating])
#         @transform :name = name
#     end
# end

# n = tbl.Name[1:100][1]
# grdata = [get_rating(n[1]) for n in tbl.Name[1:100]]

# grdata1 = reduce(vcat, grdata)

# JDF.save("grdata.jdf", grdata1)

grdata1 = JDF.load("grdata.jdf") |> DataFrame

# load the data from the dataset
tbl = JDF.load("../kifu-depot-games-for-ranking.jdf/") |> DataFrame
using BadukGoWeiqiTools: load_namesdb
const NAMESDB = load_namesdb()

pings = @chain JDF.load("../pings_hist.jdf/") begin
    DataFrame
    @transform :date = :date - Day(1)
    select([:date, :eng_name_old, :Rating])
end

tbl1 = @chain tbl begin
    @transform begin
        :black = get(NAMESDB, :black, "")
        :white = get(NAMESDB, :white, "")
    end
    @subset :black != ""
    @subset :white != ""
    innerjoin(rename(pings, :Rating => :br), on = [:black => :eng_name_old, :date => :date])
    innerjoin(rename(pings, :Rating => :wr), on = [:white => :eng_name_old, :date => :date])
    innerjoin(rename(grdata1, :Rating => :gbr), on = [:black => :name, :date => :Date])
    innerjoin(rename(grdata1, :Rating => :gwr), on = [:white => :name, :date => :Date])
end

function wp(r1, r2)
    white_advantage = 0
    power = (r2 - r1 + white_advantage) / 400
    denom = 1 + 10^power
    1 / denom
end


tbl2 = @chain tbl1 begin
    @transform begin
        :wp1 = wp(:br, :wr)
        :wp2 = wp(:gbr, :gwr)
    end
    @transform begin
        :myll = -ifelse(:who_win == "B", log(:wp1), log(1 - :wp1))
        :goll = -ifelse(:who_win == "B", log(:wp2), log(1 - :wp2))
        :yr = year(:date)
    end
    groupby(:yr)
    @combine(:myll = sum(:myll), :goll = sum(:goll))
    @transform :mine_better = :myll < :goll
end

using FloatingTableView

browse(tbl2)