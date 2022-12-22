
# if false
#     using PackageCompiler
#     create_sysimage(["Alert",
# "BadukGoWeiqiTools",
# "CSV",
# "Chain",
# "DataFrameMacros",
# "DataFrames",
# "GLM",
# "Glob",
# "JDF",
# "LoopVectorization",
# "ProgressMeter",
# "RCall",
# "StatsBase",
# "TableScraper",
# "TimeZones"
# ],
# sysimage_path="sysimage.dll",
# # script="schedule.jl"
# )

# end

# using Pkg
# Pkg.build("TimeZones")
# using TimeZones
# TimeZones.build()
include(raw"C:\weiqi\web-scraping\0-initial-run.jl")
include(raw"C:\weiqi\web-scraping\1a-collect_komi_sgf.jl")
include(raw"C:\git\baduk-go-weiqi-ratings\1_ranking.jl")
include(raw"C:\git\baduk-go-weiqi-ratings\1-make-links-to-kifu.jl")
include(raw"C:\git\baduk-go-weiqi-ratings\1b-make-links-head-to-head.jl")
include(raw"C:\git\baduk-go-weiqi-ratings\1c_knit-replace.jl")
include(raw"C:\git\baduk-go-weiqi-ratings\1d_more_stuff.jl")

# ["Alert",
# "BadukGoWeiqiTools",
# "CSV",
# "Chain",
# "DataFrameMacros",
# "DataFrames",
# "GLM",
# "Glob",
# "JDF",
# "LoopVectorization",
# "ProgressMeter",
# "RCall",
# "StatsBase",
# "TableScraper",]