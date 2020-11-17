using SOtoZulip
using SOtoZulip: prune_questions
using Underscores
using LoggingFacilities, Logging

include("../configuration.jl")

logger = TimestampTransformerLogger(current_logger(), BeginningMessageLocation();
                                              format = "yyyy-mm-dd HH:MM:SS")
global_logger(logger)

global_zulip!(email = EMAIL, apikey = API_KEY, ep = ZULIP_EP)

const db = getdb(SODB)

qs = @_ get_questions(db)

for qss in Iterators.partition(qs, 50)
    prune_questions(db, qss)
end
