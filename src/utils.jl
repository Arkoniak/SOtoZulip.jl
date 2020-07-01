# DB related

getdb(dbname) = SQLite.DB(dbname)

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

function process_post(x)
    html_body = @_ parsehtml(x.body) |> __.root |> matchFirst(sel"body", __)
    io = IOBuffer()
    print_href(io, x.owner.display_name, x.owner.link)
    print(io, " asks: ")
    print_href(io, x.title, x.link)
    print(io, "\n")
    print_unixtime(io, x.creation_date)
    println(io, "\t**Score: $(x.score)\tAnswers: $(x.answer_count)**\n")
    @_ process_post_body(html_body, io) |> String(take!(__))
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

function process_questions(qs, db; zulip = ZulipGlobal.client, to = "stackoverflow", type = "stream")
    for item in reverse(qs.items)
        status, msg_id, title = qstatus(db, item)
        status == "known" && continue

        zulip_msg = process_post(item)
        if status == "new"
            res = sendMessage(zulip; to = to, type = type, content = zulip_msg, topic = item.title)
            if get(res, :result, "fail") == "success"
                addquestion!(db, item, res)
            else
                @error "Get bad response from zulip server: $res"
            end
        else # status == "update"
            @show zulip_msg, title
            @show msg_id
            @show to
            @show type
            @show zulip
            res = updateMessage(zulip, msg_id; to = to, type = type, content = zulip_msg, topic = title)
            if get(res, :result, "fail") == "success"
                updquestion!(db, item)
            else
                @error "Get bad response from zulip server: $res"
            end
        end
        @info "Processed question $(item.question_id)"
    end
end

##########################################
# Answers
struct Owner
    display_name::String
    link::String
end

struct Answer
    is_accepted::Bool
    body::String
    answer_id::Int
    question_id::Int
    creation_date::Int
    last_activity_date::Int
    score::Int
    owner::Owner
end
function Answer(answer)
    is_accepted = get(answer, :is_accepted, false)
    body = get(answer, :body, "")
    answer_id = get(answer, :answer_id, 0)
    question_id = get(answer, :question_id, 0)
    creation_date = get(answer, :creation_date, 0)
    last_activity_date = get(answer, :last_activity_date, 0)
    score = get(answer, :score, 0)
    owner = Owner(get(answer, :owner, nothing))

    Answer(is_accepted, body, answer_id, question_id, creation_date, last_activity_date, score, owner)
end

Owner(::Nothing) = Owner("Unknown", "")
function Owner(owner)
    return Owner(get(owner, :display_name, "Unknown"), get(owner, :link, ""))
end

function msg(x::Answer)
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
    return @_ process_post_body(html_body, io) |> String(take!(__))
end


function process(answer::Answer, db; zulip = ZulipGlobal.client, to = "stackoverflow", type = "stream")
    status, msg_id, title = astatus(db, answer)
    if (isempty(title)) & (status != "new")
        # This is some sort of error
        # It should never happen
        @error "Empty title for question: " * string(answer.question_id)
        return nothing
    end
    status == "known" && return nothing

    zulip_msg = msg(answer)
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

function process_answers(answers, db; zulip = ZulipGlobal.client, to = "stackoverflow", type = "stream")
    for x in answers
        for item in get(x, :items, [])
            answer = Answer(item)
            process(answer, db, zulip = zulip, to = to, type = type)
        end
    end
end
