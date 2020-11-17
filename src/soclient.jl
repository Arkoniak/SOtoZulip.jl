struct SOError{T} <: Exception
    msg::T
end

struct SOClient
    ep::String
end

function SOClient(; ep = "https://api.stackexchange.com", api_version = "2.2", use_globally = true)
    ep = ep * "/" * api_version * "/"

    client = SOClient(ep)
    if use_globally
        SOGlobal[] = client
    end

    return client
end

const SOGlobal = Ref(SOClient(; use_globally = false))

########################################
# JSON structures
########################################
mutable struct TagQuestionId
    tags::Vector{String}
    question_id::Int
end
TagQuestionId() = TagQuestionId(String[], -1)
StructTypes.StructType(::Type{TagQuestionId}) = StructTypes.Mutable()

mutable struct SOResponse{T}
    items::Vector{T}
    has_more::Bool
    quota_max::Int
    quota_remaining::Int
end
SOResponse{T}() where T = SOResponse(T[], false, 0, 0)
StructTypes.StructType(::Type{<:SOResponse}) = StructTypes.Mutable()

mutable struct Owner
    display_name::String
    link::String
end
Owner() = Owner("Unknown", "")
StructTypes.StructType(::Type{Owner}) = StructTypes.Mutable()

mutable struct Question
    tags::Vector{String}
    question_id::Int
    body::String
    owner::Owner
    title::String
    link::String
    creation_date::Int
    last_activity_date::Int
    score::Int
    answer_count::Int
    is_answered::Bool
end
Question() = Question([], 0, "", Owner(), "", "", 0, 0, 0, 0, false)
StructTypes.StructType(::Type{Question}) = StructTypes.Mutable()

mutable struct Answer
    is_accepted::Bool
    body::String
    owner::Owner
    question_id::Int
    answer_id::Int
    creation_date::Int
    last_activity_date::Int
    score::Int
end
Answer() = Answer(false, "", Owner(), 0, 0, 0, 0, 0)
StructTypes.StructType(::Type{Answer}) = StructTypes.Mutable()

########################################
# SO processing utils
########################################
function process_response(response, T = Nothing)
    headers = Dict(response.headers)
    if get(headers, "content-encoding", "") == "gzip"
        stream = response.body |> IOBuffer |> GzipDecompressorStream
        if T === Nothing
            return JSON3.read(stream)
        else
            return JSON3.read(stream, T)
        end
    else
        # Do not know, what to do, let's throw an error
        @error "In stackoverflow response unknown content-encoding " * get(headers, "content-encoding", "\"empty field\"")
        throw(SOError("Not gzip encoded header: " * JSON3.write(headers)))
    end
end

function searchtag(client::SOClient = SOGlobal[]; params...)
    params = Dict(params) |> HTTP.URIs.escapeuri
    url = client.ep * "search?"
    response = HTTP.get(url * params)

    return process_response(response, SOResponse{TagQuestionId})
end

getquestions(qids; params...) = getquestions(SOGlobal[], qids; params...)
function getquestions(client::SOClient, qids; params...)
    url = client.ep * "questions/"
    qids = join(qids, ";") |> HTTP.URIs.escapeuri
    params = Dict(params) |> HTTP.URIs.escapeuri

    response = HTTP.get(url * qids * "?" * params)

    return process_response(response, SOResponse{Question})
end

getqanswers(qids; params...) = getqanswers(SOGlobal[], qids; params...)
function getqanswers(client::SOClient, qids; params...)
    url = client.ep * "questions/"
    qids = join(qids, ";") |> HTTP.URIs.escapeuri
    params = Dict(params) |> HTTP.URIs.escapeuri

    response = HTTP.get(url * qids * "/answers?" * params)
    
    return process_response(response, SOResponse{Answer})
end

getallqanswers(qids; params...) = getallqanswers(SOGlobal[], qids; params...)
function getallqanswers(client::SOClient, qids; params...)
    answers = []
    hasmore = true
    page = 1
    while hasmore
        res = getqanswers(client, qids; page = page, params...)
        push!(answers, res)
        page += 1
        hasmore = res.has_more
    end

    return answers
end
