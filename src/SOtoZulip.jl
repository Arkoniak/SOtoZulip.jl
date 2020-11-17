module SOtoZulip
using Base64
using HTTP
using JSON3
using Underscores
using CodecZlib
using Gumbo
using Cascadia
using Cascadia: matchFirst
using SQLite
using MD5
using Dates
using StructTypes

# Zulip related things
export ZulipClient, sendMessage, global_zulip!
export SOClient, searchtag, getquestions, getqanswers, getallqanswers
export show_query, getdb
export process_question, process_answers
export invalidate_answer, invalidate_question
export get_questions, clean, get_qids

include("zulipclient.jl")
include("soclient.jl")
include("utils.jl")
include("dbwrapper.jl")

end # module
