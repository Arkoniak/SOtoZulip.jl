# DB related

getdb(dbname) = SQLite.DB(dbname)
get_qids(v) = @_ map(_.question_id, v)
clean(questions) = @_ filter("julia" in _.tags, questions.items) |> filter(_.question_id > 0, __)

function show_query(db, query; params = (), n = 1)
    stmt = SQLite.Stmt(db, query)
    res = DBInterface.execute(stmt, params)
    for (i, row) in enumerate(res)
        println(row)
        i >= n && break
    end
end

function print_href(io, text, href)
    print(io, "[", text, "](", href, ")")
end

function print_unixtime(io, tm)
    print(io, "**[")
    print(io, Dates.format(Dates.unix2datetime(tm), "dd u yyyy HH:MM:SS"))
    print(io, "]**")
end

function process_post(x, body = nothing)
    html_body = @_ parsehtml(x.body) |> __.root |> matchFirst(sel"body", __)
    io = IOBuffer()
    ownername = x.owner.display_name
    ownerlink = x.owner.link
    print_href(io, ownername, ownerlink)
    print(io, " asks: ")
    print_href(io, x.title, x.link)
    print(io, "\n")
    print_unixtime(io, x.creation_date)
    println(io, "\t**Score: $(x.score)\tAnswers: $(x.answer_count)**\n")
    if isnothing(body)
        return @_ process_post_body(html_body, io) |> String(take!(__))
    else
        print(io, body)
        return String(take!(io))
    end
end

function process_post_body(x::HTMLText, io, list)
    print(io, x.text)

    return io
end

function process_post_body(x, io = IOBuffer(), list = "")
    if tag(x) == :pre
        # It should be large code block
        print(io, "```\n", nodeText(x), "```\n")
    elseif tag(x) == :code
        # This is inline code
        print(io, "`", nodeText(x), "`")
    elseif tag(x) == :a
        # Link
        print(io, "[", nodeText(x), "](", x.attributes["href"], ")")
    elseif tag(x) == :p
        # Paragraph
        @_ foreach(process_post_body(_, io, list), x.children)
        print(io, "\n")
    elseif tag(x) == :ul
        @_ foreach(process_post_body(_, io, "ul"), x.children)
        print(io, "\n")
    elseif tag(x) == :li
        # In the future, here should be if/else for different kinds of list (numbered, unnumbered, nested)
        print(io, "+ ")
        @_ foreach(process_post_body(_, io, ""), x.children)
        print(io, "\n")
    elseif tag(x) == :blockquote
        # Quote
        print(io, "```quote\n")
        # Bad thing is we are losing all formatting, but let's hope that it is not going to be an issue in most cases
        print(io, nodeText(x))
        print(io, "\n```\n")
    elseif tag(x) == :strong
        print(io, "**")
        @_ foreach(process_post_body(_, io, list), x.children)
        print(io, "**")
    else
        # Not much left to do
        @_ foreach(process_post_body(_, io, list), x.children)
    end

    return io
end

function process_question(item, db; zulip = ZulipGlobal[], to = "stackoverflow", type = "stream")
    status, msg_id, title = qstatus(db, item)
    status == "known" && return

    zulip_msg = process_post(item)
    if length(zulip_msg) > 9900
        zulip_msg = process_post(item, "Message is too long, please read it on [stackoverflow.com]($(item.link))")
    end
    if status == "new"
        try
            res = sendMessage(zulip; to = to, type = type, content = zulip_msg, topic = item.title)
            if get(res, :result, "fail") == "success"
                addquestion!(db, item, res)
            else
                @error "Get bad response from zulip server: $res"
            end
        catch err
            @info "Received error from the server"
            @info zulip_msg
            @info item.title
            @info item
            rethrow()
        end
    else # status == "update"
        res = updateMessage(zulip, msg_id; to = to, type = type, content = zulip_msg, topic = title)
        if get(res, :result, "fail") == "success"
            updquestion!(db, item)
        else
            @error "Get bad response from zulip server: $res"
        end
    end
    @info "Processed question $(item.question_id)"
end

##########################################
# Answers

function msg(x::Answer, body = nothing)
    html_body = @_ parsehtml(x.body) |> __.root |> matchFirst(sel"body", __)
    io = IOBuffer()
    if x.is_accepted
        print(io, "✅ ")
    end
    print_href(io, x.owner.display_name, x.owner.link)
    print(io, " ")
    print_href(io, "answered", "https://stackoverflow.com/a/$(x.answer_id)")
    print(io, ":\n")
    print_unixtime(io, x.creation_date)
    println(io, " **Score: $(x.score)**\n")
    if isnothing(body)
        return @_ process_post_body(html_body, io) |> String(take!(__))
    else
        print(io, body)
        return String(take!(io))
    end
end


function process(answer::Answer, db; zulip = ZulipGlobal[], to = "stackoverflow", type = "stream")
    status, msg_id, title = astatus(db, answer)
    if (isempty(title)) & (status != "new")
        # This is some sort of error
        # It should never happen
        @error "Empty title of the question: " * string(answer.question_id)
        return nothing
    end
    status == "known" && return nothing

    zulip_msg = msg(answer)
    if length(zulip_msg) > 9900
        zulip_msg = msg(answer, "Message is too long, please read it on [stackoverflow.com](https://stackoverflow.com/a/$(answer.answer_id))")
    end
    if status == "new"
        res = sendMessage(zulip; to = to, type = type, content = zulip_msg, topic = title)
        if get(res, :result, "fail") == "success"
            add!(db, answer, res)
        else
            @error "Get bad response from zulip server: $res"
        end
    else # status == "update"
        res = updateMessage(zulip, msg_id; to = to, type = type, content = zulip_msg, topic = title)
        if get(res, :result, "fail") == "success"
            update!(db, answer)
        else
            @error "Get bad response from zulip server: $res"
        end
    end
    @info "Processed answer_id $(answer.answer_id)"
end

function process_answers(answers, db; zulip = ZulipGlobal[], to = "stackoverflow", type = "stream")
    for x in answers
        for answer in x.items
            process(answer, db, zulip = zulip, to = to, type = type)
        end
    end
end

########################################
# Cleanup section
########################################

function remove_question(db, qid; zulip = ZulipGlobal[])
    msgid = get_question(db, qid)
    answids = get_answers(db, qid)
    if isempty(msgid)
        @info "Question $qid is not found"
        return
    end
    msgid = msgid[1]
    try
        deleteMessage(zulip, msgid)
    catch err
        @error err
    end
    for answid in answids
        try
            deleteMessage(zulip, answid)
        catch err
            @error err
        end
    end
    drop_question!(db, qid)
end

function prune_questions(db, qs; zulip = ZulipGlobal[], tagword = "julia")
    qids = @_ map(_.qid, qs)
    soqs = getquestions(qids; site = "stackoverflow", pagesize = length(qids))
    allowed = @_ filter(tagword in _.tags, soqs.items) |> map(_.question_id, __)
    for q in qs
        if !(q.qid in allowed)
            @info "Removing question '$(q.title)'"
            remove_question(db, q.qid, zulip = zulip)
        end
    end
end

