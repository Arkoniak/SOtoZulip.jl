# Small pirating and type instability wouldn't hurt
Gumbo.:tag(x::HTMLText) = nothing

function print_href(io, text, href)
    print(io, "[", text, "](", href, ")")
end

function process_post(x)
    html_body = @_ parsehtml(x.body) |> __.root |> matchFirst(sel"body", __)
    io = IOBuffer()
    print_href(io, x.owner.display_name, x.owner.link)
    print(io, " asks: ")
    print_href(io, x.title, x.link)
    print(io, "\n")
    println(io, "**Answered**: ", x.is_answered ? "✅" : "❌", "\t**Score**: $(x.score)\t**Answers**: $(x.answer_count)\n")
    @_ process_post_body(html_body, io) |> String(take!(__))
end

function process_post_body(x, io = IOBuffer())
    if isnothing(tag(x))
        # HTMLText
        print(io, x.text)
    elseif tag(x) == :pre
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
        foreach(y -> process_post_body(y, io), x.children)
        print(io, "\n")
    elseif tag(x) == :blockquote
        # Quote
        print(io, "```quote\n")
        # Bad thing is we are losing all formatting, but let's hope that it is not going to be an issue in most cases
        print(io, nodeText(x))
        print(io, "\n```\n")
    else
        # Not much left to do
        foreach(y -> process_post_body(y, io), x.children)
    end

    return io
end
