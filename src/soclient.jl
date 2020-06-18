struct SOError{T} <: Exception
    msg::T
end

struct SOClient
    ep::String
end

mutable struct SOOpts
    client::SOClient
end

const SOGlobal = SOOpts(SOClient(""))

function SOClient(; ep = "https://api.stackexchange.com", api_version = "2.2", use_globally = true)
    ep = ep * "/" * api_version * "/"

    client = SOClient(ep)
    if use_globally
        SOGlobal.client = client
    end
end

function process_response(response)
    headers = Dict(response.headers)
    if get(headers, "content-encoding", "") == "gzip"
        return response.body |> IOBuffer |> GzipDecompressorStream |> JSON3.read
    else
        # Do not know, what to do, let's throw an error
        @error "In stackoverflow response unknown content-encoding " * get(headers, "content-encoding", "\"empty field\"")
        throw(SOError("Not gzip encoded header: " * JSON3.write(headers)))
    end
end

function searchtag(client::SOClient = SOGlobal.client; params...)
    params = Dict(params) |> HTTP.URIs.escapeuri
    url = client.ep * "search?"
    response = HTTP.get(url * params)

    return process_response(response)
end

getquestions(qids; params...) = getquestions(SOGlobal.client, qids; params...)
function getquestions(client::SOClient, qids; params...)
    url = client.ep * "questions/"
    qids = join(qids, ";") |> HTTP.URIs.escapeuri
    params = Dict(params) |> HTTP.URIs.escapeuri

    response = HTTP.get(url * qids * "?" * params)

    return process_response(response)
end

getqanswers(qids; params...) = getqanswers(SOGlobal.client, qids; params...)
function getqanswers(client::SOClient, qids; params...)
    url = client.ep * "questions/"
    qids = join(qids, ";") |> HTTP.URIs.escapeuri
    params = Dict(params) |> HTTP.URIs.escapeuri

    response = HTTP.get(url * qids * "/answers?" * params)
    
    return process_response(response)
end

getallqanswers(qids; params...) = getallqanswers(SOGlobal.client, qids; params...)
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
