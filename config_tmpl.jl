using Logging, LoggingExtras, Dates

const EMAIL = # Bot email
const API_KEY = # Bot api key
const ZULIP_EP = "https://julialang.zulipchat.com/"

const SODB = "db/sodb.sqlite"
const LOGS_DIR = "<path to logs>"

const date_format = "yyyy-mm-dd HH:MM:SS"

timestamp_logger(logger) = TransformerLogger(logger) do log
    merge(log, (; message = "[$(Dates.format(now(), date_format))] $(log.message)"))
end

ConsoleLogger(stdout, show_limited = false) |> timestamp_logger |> global_logger
