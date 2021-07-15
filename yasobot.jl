using Underscores
using SOtoZulip
using Dates
using JSON3

include("configuration.jl")

const db = getdb(SODB)
global_zulip!(email = EMAIL, apikey = API_KEY, ep = ZULIP_EP)
SOtoZulip.SOGlobal[] = SOtoZulip.SOClient(api_version = "2.3")

function log_quota(quota)
    if quota >= 10
        @info "Quota remaining: $quota"
    else
        @error "Quota remaining: $quota"
    end
end

const hh = hour(Dates.now())

try
    # Update and create fresh questions
    juliatag = searchtag(; order = "desc", sort = "creation", tagged = "julia", site = "stackoverflow", pagesize = 50)
    log_quota(juliatag.quota_remaining)
    qids = get_qids(clean(juliatag))
    questions = getquestions(qids; order = "desc", sort = "creation",
                             site = "stackoverflow", filter = "!9_bDDxJY5",
                             pagesize = 50)
    log_quota(questions.quota_remaining)

    open(joinpath(LOGS_DIR, "so_bot_new_questions-$(hh).json"), "w") do f
        write(f, JSON3.write(questions))
    end

    questions = clean(questions)
    qids = get_qids(questions)
    process_question.(reverse(questions), Ref(db))

    answ = SOtoZulip.getallqanswers(qids; order = "desc", sort = "creation",
                                 site = "stackoverflow", filter = "!9_bDE(fI5", 
                                 pagesize = 100)
    log_quota(answ[end].quota_remaining)

    process_answers(answ, db)

    # Update active questions
    juliatag = searchtag(; order = "desc", sort = "activity", tagged = "julia", site = "stackoverflow", pagesize = 50)
    log_quota(juliatag.quota_remaining)
    qids = get_qids(clean(juliatag))
    questions = getquestions(qids; order = "desc", sort = "creation",
                             site = "stackoverflow", filter = "!9_bDDxJY5",
                             pagesize = 50)
    log_quota(questions.quota_remaining)

    open(joinpath(LOGS_DIR, "so_bot_active_questions-$(hh).json"), "w") do f
        write(f, JSON3.write(questions))
    end
    questions = clean(questions)
    qids = get_qids(questions)

    process_question.(reverse(questions), Ref(db))

    answ = SOtoZulip.getallqanswers(qids; order = "desc", sort = "creation",
                                 site = "stackoverflow", filter = "!9_bDE(fI5", 
                                 pagesize = 100)
    log_quota(answ[end].quota_remaining)

    process_answers(answ, db)
catch err
    # This one is needed for telegram notification
    @error "SOtoZulipBOT: Exception during data processing" exception=(err, catch_backtrace())
    # This one goes to logs
    throw(err)
end
