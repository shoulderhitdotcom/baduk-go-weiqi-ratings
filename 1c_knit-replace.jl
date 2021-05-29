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

try
    run(`git add index.md`)
    run(`git commit -m "daily update $to_date main"`)
    run(`git push`)
    alert("Seems to have succeeded pushing index.md")
catch e
    alert("You process failed index.md")
    raise(e)
end


cd(PATH)
# for the player games use the template to generate all the stuff

# names_to_update is from 1-make-links-to-kifu
@threads for i in 1:length(names_to_update)
    name = names_to_update[i]
    if !ismissing(name)
        replace_in_file("player-games-template.jmd", "./player-games-md/jmd/$name.jmd", ("{{name}}"=>name, ))
    end
end

cd(PATH)
for i in 1:length(names_to_update)
    name = names_to_update[i]
    if !ismissing(name)
        weave("./player-games-md/jmd/$name.jmd", out_path = "./player-games-md/tmp/$name.md", doctype = "github")
    end
end

cd(PATH)
@threads for i in 1:length(names_to_update)
    name = names_to_update[i]
    if !ismissing(name)
        replace_in_file("./player-games-md/tmp/$name.md", "./player-games-md/md/$name.md", replacements)
    end
end

try
    run(`git add ./player-games-md/md/\*`)
    run(`git commit -m "daily update all games $to_date "`)
    run(`git push`)
    alert("Seems to have succeeded")
catch e
    alert("You process failed")
    raise(e)
end

#############################################################################################
# Head to head
#############################################################################################

head_to_head_sets = @chain df begin
    @where @. !ismissing(:black)
    @where @. !ismissing(:white)
    @where in.(:black, Ref(names_to_update))
    @where in.(:white, Ref(names_to_update))
    Dict(Set((n1, n2)) => true for (n1, n2) in zip(_.black, _.white))
    keys()
    collect.()
    filter(x->length(x) == 2, _) # weird case where kim jiseok played himself
end

# names_to_update is from 1-make-links-to-kifu
cd(PATH)
for (name1, name2) in head_to_head_sets
    replace_in_file("head-to-head-template.jmd", "./head-to-head-md/jmd/$name1-$name2.jmd", ("{{name1}}"=>name1, "{{name2}}"=>name2))
end

cd(PATH)
for (name1, name2) in head_to_head_sets
    # if !isfile("./head-to-head-md/tmp/$name1-$name2.md")
        weave("./head-to-head-md/jmd/$name1-$name2.jmd", out_path = "./head-to-head-md/tmp/$name1-$name2.md", doctype = "github")
    # end
end

cd(PATH)
@threads for i in 1:length(head_to_head_sets)
    @inbounds name1, name2 = head_to_head_sets[i]
    replace_in_file("./head-to-head-md/tmp/$name1-$name2.md", "./head-to-head-md/md/$name1-$name2.md", replacements)
end

try
    run(`git add ./head-to-head-md/md/\*`)
    run(`git commit -m "daily update all head to head $to_date "`)
    run(`git push`)
    alert("Seems to have succeeded doing head to head")
catch e
    alert("You process failed")
    raise(e)
end