module SOtoZulip
using Base64
using HTTP
using JSON3
using Underscores
using CodecZlib
using Gumbo
using Cascadia
using Cascadia: matchFirst

# Zulip related things
export ZulipClient, sendMessage
export SOClient, searchtag, getquestions

include("zulipclient.jl")
include("soclient.jl")
include("utils.jl")

end # module
