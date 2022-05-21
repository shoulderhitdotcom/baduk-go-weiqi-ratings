using Chain, DataFrames, DataFrameMacros

tbl1 = @chain tbl begin
    @transform begin
        :winner = :who_win == "B" ? :black : :white
        :loser = :who_win == "B" ? :white : :black
    end
    @transform :groupie = Set([:winner, :loser])
end

tbl2 = @chain tbl1 begin
    unique([:winner, :loser, :groupie])
    groupby(:groupie)
    combine(nrow)
    @subset :nrow == 1
end

tbl3 = @chain tbl1 begin
    innerjoin(select(tbl2, :groupie), on=:groupie)
    groupby([:winner, :loser])
    combine(nrow)
    sort!(:nrow, rev=true)
end

using BadukGoWeiqiTools: load_namesdb

const NAMES=load_namesdb()

tbl3 = @chain tbl1 begin
    innerjoin(select(tbl2, :groupie), on=:groupie)
    groupby([:winner, :loser])
    combine(nrow)
    sort!(:nrow, rev=true)
    @subset !(:winner in ("AlphaGo", "AlphaGoZero", "ELFOpenGo", "絶芸", "DeepZenGo"))
    @subset :nrow >= 7
    @transform begin
        :winner_eng = try NAMES[:winner] catch e; "" end
        :loser_eng = try NAMES[:loser] catch e; "" end
    end
    # @subset :winner_eng == "Shin Jinseo"
end


using CSV, Statistics, DataFrames, DataFrameMacros, Chain, Dates


# @time pings_hist = mapreduce(vcat, Date(2021, 1, 1):Day(1):Date(2021,10,21)) do date
#     if isfile("records/$(string(date)) pings.csv")
#         pings_old = CSV.read(
#             "records/$(string(date)) pings.csv", DataFrame;
#             select=[:name, :estimate, :std_error]
#         )
#         pings_old[!, :date] .= date
#         return pings_old
#     else
#         return DataFrame()
#     end
# end

pings_hist = JDF.load("pings_hist.jdf") |> DataFrame

latest_date = maximum(pings_hist.date)


tmp = @chain pings_hist begin
    @subset latest_date - Dates.Day(round(10*365.25)) <= :date
    @aside min_rating = minimum(_.Rating)
    @transform :estimate = log(:Rating - min_rating + 0.01)
    select!([:date, :name, :eng_name_old, :estimate])
end

# normalise the ratings so that it has mean 0 and standard deviation 1
tmp2 = @chain tmp begin
    groupby(:date)
    @combine(mean(:estimate), std(:estimate), median(:estimate))
    innerjoin(tmp, on=:date)
    @transform begin
        :estimate_normal = (:estimate - :estimate_mean)/:estimate_std
    end
    select!(:date, :name, :estimate_normal)
end

min_date = minimum(tmp2.date)

# for success dates, compute the lm
function new_ratings(old_date, new_date)
    global result
    old_date_data = @chain result begin
        @subset :date == old_date
        unique([:date, :name])
    end

    new_date_data = @chain tmp2 begin
        @subset :date == new_date
        unique([:date, :name])
    end

    m = @chain old_date_data begin
        vcat(new_date_data)
        unstack(:name, :date, :estimate_normal; renamecols=name->replace("date_$name", "-"=>"_"))
        rename(_, [n=>"n$i" for (i,n) in enumerate(names(_))]...)
        @subset !ismissing(:n2) && !ismissing(:n3)
        _[1:100, :]
        sort!(:n3, rev=true)
        lm(@formula(n2~n3), _)
    end

    # score the model on the full dataset
    @chain new_date_data begin
        @transform :estimate_normal = coef(m)[1] + :estimate_normal*coef(m)[2]
    end

    result = vcat(result, new_date_data)
end

dates = sort(unique(tmp2.date))

result = @chain tmp2 begin
    @subset :date == min_date
end

# new_ratings(dates[1], dates[2])

new_date = dates[2]

@time for (old_date, new_date) in zip(dates[1:end-1], dates[2:end])
    new_ratings(old_date, new_date)
end

result

@chain result begin
    groupby(:date)
    @combine(mean(:estimate_normal), std(:estimate_normal), median(:estimate_normal))
    plot(_.estimate_normal_median)
end

@chain tmp2 begin
    @subset :name == "申眞諝"
    plot(_.estimate_normal)
end

@chain tmp2 begin
    @subset :name == "申眞諝"
    sort!(:date)
    diff(_.estimate_normal)
    findmax(_)
    # plot(_.estimate_normal)
end

@chain tmp2 begin
    @subset :name == "申眞諝"
    _[2934:2935, :]
end

@chain tmp begin
    @subset :date in (Dates.Date("2021-03-15"), Dates.Date("2021-03-16"))
    unstack(:name, :date, :estimate)
end

@chain tmp begin
    @subset :date in (Dates.Date("2021-03-15"), Dates.Date("2021-03-16"))
    groupby(:date)
    @combine(mean(:estimate), std(:estimate), length(:estimate))
end



@chain pings_hist begin
    @subset @c in.(:date, Ref([maximum(:date)- Dates.Day(4), maximum(:date) - Dates.Day(5)]))
    unstack(:name, :date, :estimate; renamecols=name->replace("date_$name", "-"=>"_"))
    rename(_, [n=>"n$i" for (i,n) in enumerate(names(_))]...)
    @subset !ismissing(:n2) && !ismissing(:n3)
    sort!(:n3, rev=true)
    @aside m = lm(@formula(n2~n3), _)
    @transform :n3_new = coef(m)[1] + :n3*coef(m)[2]
    @transform :n2_demean = @c (:n2 .- mean(:n2)) ./ std(:n2)
    @transform :n3_demean = @c (:n3 .- mean(:n3)) ./ std(:n3)
end

@chain pings_hist begin
    groupby(:date)
    @combine(mean(:estimate), std(:estimate), median(:estimate))
    # rightjoin(pings_hist, on=:date)
    # @transform begin
    #     :estimate_normal = (:estimate_std - :estimate_mean)/:estimate_std
    # end
    # @subset:name == "申眞諝"
    # plot(_.estimate_normal)
    plot(_.estimate_median)
end

using GLM

using Plots

plot(m1.n2, m1.n3)
plot!([minimum(m1.n2), maximum(m1.n2)], [minimum(m1.n3), maximum(m1.n3)], seriestype = :straightline)