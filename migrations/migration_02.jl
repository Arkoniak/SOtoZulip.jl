using SOtoZulip
using DBInterface

include("configuration.jl")

db = getdb(SODB)

########################################
# UP
########################################

queries = [
"""
ALTER TABLE questions
ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0
""",
"""
ALTER TABLE answers
ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0
"""
]

DBInterface.execute(db, "BEGIN TRANSACTION")
try
    DBInterface.execute.(Ref(db), queries)
    DBInterface.execute(db, "COMMIT TRANSACTION")
catch
    DBInterface.execute(db, "ROLLBACK")
end
