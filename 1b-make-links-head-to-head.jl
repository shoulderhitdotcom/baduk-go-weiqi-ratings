const PATH = "c:/git/baduk-go-weiqi-ratings/"
using Pkg; Pkg.activate(PATH); cd(PATH)
using Revise: includet
using DataFrames, DataFrameMacros
using Chain: @chain
using Dates: Date, Day
using JDF
using Missings: skipmissings
using Revise: includet

includet("utils.jl")

for file in readdir("head-to-head-md/md/")
    if ':' in file
        println(file)
    end
end


db = load_namesdb("NAMESDB"; force=false)

do_for_all = false

# @subset(stack(DataFrame(db), :), :value .== "Kim Jiseok")

# tbl_from_somewhere = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
#         JDF.load()
#         DataFrame()
#         @subset (:black .== "金志錫") .& (:white .== "金志錫")
#         select!(:kifu_link)
# end

## Need to selectively up date this
# function update_head_to_head_games_jdf(df, names_to_update; do_for_all = false)
    # for each player create the players's page
if do_for_all
    tmp = vcat(df.black |> unique, df.white |> unique) |> unique |> skipmissings |> first
    names_to_update = filter(n -> n != "", tmp |> collect)
end

head_to_head_sets = @chain df begin
    @subset !ismissing(:black)
    @subset !ismissing(:white)
    @subset :black in names_to_update
    @subset :white in names_to_update
    Dict(Set((n1, n2)) => true for (n1, n2) in zip(_.black, _.white))
    keys() # keys are the name pairs
    collect.() # returns an array of arays of two values
    filter(x->length(x) == 2, _) # weird case where kim jiseok played himself
    sort.() # sort the name by alphabetical order
    unique() #
end

for (name1, name2) in head_to_head_sets
    # println(name1, name2)
    head_to_head = @chain df begin
        @subset ((:black .== name1) .& (:white .== name2)) .| ((:black .== name2) .& (:white .== name1))
        @transform :name1win = ifelse((:who_win == "W") & (:white == name1) | (:who_win == "B") & (:black == name1), 1, 0)
        @transform :name1win_cum = @bycol reverse(accumulate(+, reverse(:name1win)))
        @transform :name2win_cum = @bycol reverse(accumulate(+, 1 .- reverse(:name1win)))
        @transform :cum = string(:name1win_cum) * ":" * string(:name2win_cum)
        @transform :name1win_streak = @bycol accumulate((cum, newres)->ifelse(newres == 1, cum+1, 0), reverse(:name1win)) |> reverse
        @transform :name2win_streak = @bycol accumulate((cum, newres)->ifelse(newres == 1, cum+1, 0), reverse(1 .- :name1win)) |> reverse
        select!(
            :date=>:Date,
            :comp=>:Comp,
            :black=>:Black,
            :white=>:White,
            :result=>Symbol("Game result"),
            :komi_fixed=>:Komi,
            :cum => Symbol("Cumulative $name1 vs $name2"),
            :name1win_streak=>Symbol("$name1 streak"),
            :name2win_streak=>Symbol("$name2 streak")
        )
        sort!(:Date, rev=true)
    end

    if nrow(head_to_head) > 0
        JDF.save("./head-to-head-md/jdf/$name1-$name2.jdf", head_to_head)
    end
end
