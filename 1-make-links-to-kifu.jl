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


## Need to selectively up date this
function update_player_games_jdf(; do_for_all = false)
    df = @chain "c:/weiqi/web-scraping/kifu-depot-games-with-sgf.jdf/" begin
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
        @transform! black = coalesce.(eng_name.(:black), "")
        @transform! white = coalesce.(eng_name.(:white), "")
    end

    df_for_names = @where(df, do_for_all .| (:date .== maximum(:date)))

    names_to_update = vcat(df_for_names.black, df_for_names.white) |> unique |> skipmissings |> first |> collect
    names_to_update = filter(n->n != "", names_to_update)

    # for each player create the players's page
    for name in names_to_update
        if !ismissing(name)
            if name != ""
                @chain df begin
                    @where (:black .== name) .| (:white .== name)
                    @transform Result = ifelse.(
                        ((:who_win .== "W") .& (:white .== name)) .|
                        ((:who_win .== "B") .& (:black .== name))
                        , "Win", "Lose")
                    select!(
                        :date=>:Date,
                        :comp=>:Comp,
                        :black=>:Black,
                        :white=>:White,
                        :Result,
                        :result=>Symbol("Game result"),
                        :komi_fixed=>:Komi
                        )
                    JDF.save("./player-games-md/jdf/$name.jdf", _)
                end
            end
        end
    end

    df, names_to_update
end

# this is used in the next section
df, names_to_update = update_player_games_jdf()
