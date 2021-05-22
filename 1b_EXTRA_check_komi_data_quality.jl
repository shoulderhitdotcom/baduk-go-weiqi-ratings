# fix the komi
# countmap(tbl.komi)

tbl.komi_fixed = replace(
    tbl.komi,
    6.4 => 6.5,
    8.0 => 7.5,
    750 => 7.5,
    605.0 => 6.5
)

tbl = @where(tbl, in.(:komi, Ref((6.5, 7.5))))