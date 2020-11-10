using Underscores
using SOtoZulip

include("configuration.jl")

const db = getdb(SODB)
zulip = ZulipClient(email = EMAIL, apikey = API_KEY, ep = ZULIP_EP)
soclient = SOClient()

function log_quota(quota)
    if quota >= 10
        @info "Quota remaining: $quota"
    else
        @error "Quota remaining: $quota"
    end
end

try
    # Update and create fresh questions
    juliatag = searchtag(; order = "desc", sort = "creation", tagged = "julia", site = "stackoverflow", pagesize = 50)
    log_quota(juliatag.quota_remaining)
    qids = @_ juliatag.items |> filter("julia" in _.tags, __) |> get.(__, "question_id")
    questions = getquestions(qids; order = "desc", sort = "creation",
                             site = "stackoverflow", filter = "!9_bDDxJY5",
                             pagesize = 50)

    log_quota(questions.quota_remaining)
    process_questions(questions, db)

    answ = SOtoZulip.getallqanswers(qids; order = "desc", sort = "creation",
                                 site = "stackoverflow", filter = "!9_bDE(fI5", 
                                 pagesize = 100)
    log_quota(answ[end].quota_remaining)

    process_answers(answ, db)

    # Update active questions
    juliatag = searchtag(; order = "desc", sort = "activity", tagged = "julia", site = "stackoverflow", pagesize = 50)
    log_quota(juliatag.quota_remaining)
    qids = @_ juliatag.items |> filter("julia" in _.tags, __) |> get.(__, "question_id")
    questions = getquestions(qids; order = "desc", sort = "creation",
                             site = "stackoverflow", filter = "!9_bDDxJY5",
                             pagesize = 50)

    log_quota(questions.quota_remaining)
    process_questions(questions, db)

    answ = SOtoZulip.getallqanswers(qids; order = "desc", sort = "creation",
                                 site = "stackoverflow", filter = "!9_bDE(fI5", 
                                 pagesize = 100)
    log_quota(answ[end].quota_remaining)

    process_answers(answ, db)
catch err
    # This one is needed for telegram notification
    @error err
    # This one goes to logs
    throw(err)
end
