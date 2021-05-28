const PATH = "c:/git/baduk-go-weiqi-ratings/"
using Pkg; Pkg.activate(PATH); cd(PATH)
using Revise: includet
using DataFrames, DataFramesMeta
using Chain: @chain
using Dates: Date, Day
using JDF
using Missings: skipmissings
using Revise: includet

includet("utils.jl")

db = load_namesdb("NAMESDB"; force=false)

@where(stack(DataFrame(db), :), :value .== "Kim Jiseok")

tbl_from_somewhere = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
        JDF.load()
        DataFrame()
        @where (:black .== "金志錫") .& (:white .== "金志錫")
        select!(:kifu_link)
end

## Need to selectively up date this
function update_head_to_head_games_jdf(df, names_to_update; do_for_all = false)
    # for each player create the players's page
    if do_for_all
        tmp = vcat(df.black |> unique, df.white |> unique) |> unique |> skipmissings |> first
        names_to_update = filter(n -> n != "", tmp |> collect)
    end

    sets = @chain df begin
        @where @. !ismissing(:black)
        @where @. !ismissing(:white)
        @where in.(:black, Ref(names_to_update))
        @where in.(:white, Ref(names_to_update))
        Dict(Set((n1, n2)) => true for (n1, n2) in zip(_.black, _.white))
        keys()
        collect.()
        filter(x->length(x) == 2, _) # weird case where kim jiseok played himself
    end

    for (name1, name2) in sets
        println(name1, name2)
        head_to_head = @chain df begin
            @where ((:black .== name1) .& (:white .== name2)) .| ((:black .== name2) .& (:white .== name1))
        end

        if nrow(head_to_head) > 0
            println("$name1 - $name2")
            JDF.save("./head_to_head-md/jdf/$name1-$name2.jdf", head_to_head)
        end
    end
end

# this is used in the next section
update_head_to_head_games_jdf(df, names_to_update);
