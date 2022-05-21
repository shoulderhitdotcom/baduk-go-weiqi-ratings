using LibPQ, Tables, CSV
using TableIO
using BadukGoWeiqiTools: load_namesdb

const NAMESDB = load_namesdb("NAMESDB")

DataFrame(NAMESDB)

name_to_eng_name = DataFrame(
    name = collect(keys(NAMESDB)),
    english_name = collect(values(NAMESDB))
)


conn = LibPQ.Connection("postgresql://xiaodai_demo_db_connection:EayN_LkQcVuzZLe3p8HFcsxJwrT7@db.bit.io")

cols = join(["$name   text" for name in names(name_to_eng_name)], ",\n")

result = execute(conn, """
    CREATE TABLE "xiaodai/baduk-go-weiqi"."name_to_english_name_mapping" (
        $cols
    );
""")

TableIO.write_table!(conn, "\"xiaodai/baduk-go-weiqi\".name_to_english_name_mapping", name_to_eng_name)
