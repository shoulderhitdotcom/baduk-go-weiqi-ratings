using Weave
using Base.Threads: @threads; println(Threads.nthreads())

function replace_in_file(inpath, outpath, replacements)
    open(inpath) do file
        outfile = open(outpath, "w")
        while !eof(file)
            line = readline(file)
            for (in, replace_with) in replacements
                line = replace(line, in=>replace_with)
            end
            write(outfile, line)
            write(outfile, "\n")
        end
        close(outfile)
    end
end

replacements = (
    "{{ngames}}" => string(nrow(games)),
    "{{from_date}}" =>from_date,
    "{{to_date}}" => to_date,
    "{{elo_white75_adv}}" => string(round(Int, white75_advantage*400/log(10))),
    "{{elo_black65_adv}}" => string(round(Int, black65_advantage*400/log(10))),
    "{{ping_white75_adv}}" => string(round(white75_advantage, digits=2)),
    "{{ping_black65_adv}}" => string(round(black65_advantage, digits=2)),
    "```" => "\n"
)

weave("index.jmd", out_path = "index-tmd.md", doctype = "github")
replace_in_file("index-tmd.md", "index.md", replacements)

# for the player games use the template to generate all the stuff
names = vcat(df.black, df.white) |> unique
@threads for i in 1:lenght(names)
    name = names
    if !ismissing(name)
        replace_in_file("player-games-template.jmd", "./player-games-md/jmd/$name.jmd", ("{{name}}"=>name, ))
        weave("./player-games-md/jmd/$name.jmd", out_path = "./player-games-md/tmp/$name.md", doctype = "github")
        replace_in_file("./player-games-md/tmp/$name.md", "./player-games-md/md/$name.md", replacements)
    end
end

try
    run(`git add index.md`)
    run(`git commit -m "daily update $to_date main"`)
    run(`git push`)
    alert("Seems to have succeeded pushing index.md")
catch e
    alert("You process failed index.md")
    raise(e)
end

try
    for file in readdir("./player-games-md/md/")
        run(`git add ./play-games-md/md/$file`)
    end
    run(`git commit -m "daily update all games $to_date "`)
    run(`git push`)
    alert("Seems to have succeeded")
catch e
    alert("You process failed")
    raise(e)
end