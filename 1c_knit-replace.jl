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
