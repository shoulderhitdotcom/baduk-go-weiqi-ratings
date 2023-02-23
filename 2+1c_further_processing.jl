using BadukGoWeiqiTools: NAMESDB

# NAMESDB = create_names_db(NAME_DB_JSON; force=true)

function eng_name(name)
    try
        NAMESDB[name]
    catch _
        return missing
    end
end

const OFFSET = 3800-10/log(10)*400
pings_for_md = @chain pings begin
   @where :n .> 10
   @transform eng_name = coalesce.(eng_name.(:name), Ref(""));
   @transform Rating = @. round(Int, :ping * 400 / log(10) + OFFSET)
   @transform Rank = 1:length(:ping)
   select!(:Rank, :eng_name=>"Name", :Rating, :n=>"Games Played", :name=>"Hanzi (汉字) Name", :ping => "Ping (品）*")
end



println("Rating Based on $(nrow(games)) from $(mad-Day(365*2-1)) to $mad")
println("* Ping is a reference to ancient Chinese Weiqi gradings"); println()

