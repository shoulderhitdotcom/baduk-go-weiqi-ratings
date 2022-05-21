

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

using ProgressMeter: @showprogress

pings_for_md1 = JDF.load("pings.jdf") |> DataFrame
# top20 = pings_for_md1.eng_name_old[1:20]

# names_to_update is from 1-make-links-to-kifu
cd(PATH)
@showprogress for (name1, name2) in head_to_head_sets
    # if (name1 in top20) & (name2 in top20)
        replace_in_file("head-to-head-template.jmd", "./head-to-head-md/jmd/$name1-$name2.jmd", ("{{name1}}"=>name1, "{{name2}}"=>name2))
    # end
end

cd(PATH)
@showprogress for (name1, name2) in head_to_head_sets
    # if (name1 in top20) & (name2 in top20)
        weave("./head-to-head-md/jmd/$name1-$name2.jmd", out_path = "./head-to-head-md/tmp/$name1-$name2.md", doctype = "github")
    # end
end

cd(PATH)
@showprogress for i in 1:length(head_to_head_sets)
    name1, name2 = head_to_head_sets[i]
    # if (name1 in top20) & (name2 in top20)
        @inbounds name1, name2 = head_to_head_sets[i]
        replace_in_file("./head-to-head-md/tmp/$name1-$name2.md", "./head-to-head-md/md/$name1-$name2.md", replacements)
    # end
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