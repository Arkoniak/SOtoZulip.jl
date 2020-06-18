using Underscores
using Logging, LoggingExtras, Dates
using SOtoZulip

const date_format = "yyyy-mm-dd HH:MM:SS"

timestamp_logger(logger) = TransformerLogger(logger) do log
    merge(log, (; message = "[$(Dates.format(now(), date_format))] $(log.message)"))
end

ConsoleLogger(stdout, show_limited = false) |> timestamp_logger |> global_logger

include("configuration.jl")

const db = getdb(SODB)
zulip = ZulipClient(email = EMAIL, apikey = API_KEY, ep = ZULIP_EP)
soclient = SOClient()

try
    # Update and create fresh questions
    juliatag = searchtag(; order = "desc", sort = "creation", tagged = "julia", site = "stackoverflow", pagesize = 50)
    @info "Quota remaining: $(juliatag.quota_remaining)"
    qids = @_ juliatag.items |> get.(__, "question_id")
    questions = getquestions(qids; order = "desc", sort = "creation",
                             site = "stackoverflow", filter = "!9_bDDxJY5",
                             pagesize = 50)

    @info "Quota remaining: $(questions.quota_remaining)"
    process_questions(questions, db)

    answ = SOtoZulip.getallqanswers(qids; order = "desc", sort = "creation",
                                 site = "stackoverflow", filter = "!9_bDE(fI5", 
                                 pagesize = 100)
    @info "Quota remaining: $(answ[end].quota_remaining)"

    process_answers(answ, db)

    # Update active questions
    juliatag = searchtag(; order = "desc", sort = "activity", tagged = "julia", site = "stackoverflow", pagesize = 50)
    @info "Quota remaining: $(juliatag.quota_remaining)"
    qids = @_ juliatag.items |> get.(__, "question_id")
    questions = getquestions(qids; order = "desc", sort = "creation",
                             site = "stackoverflow", filter = "!9_bDDxJY5",
                             pagesize = 50)

    @info "Quota remaining: $(questions.quota_remaining)"
    process_questions(questions, db)

    answ = SOtoZulip.getallqanswers(qids; order = "desc", sort = "creation",
                                 site = "stackoverflow", filter = "!9_bDE(fI5", 
                                 pagesize = 100)
    @info "Quota remaining: $(answ[end].quota_remaining)"

    process_answers(answ, db)
catch err
    @error err
end
