using SOtoZulip

include("configuration.jl")

db = getdb(SODB)
SOtoZulip.create_so_tables(db)
