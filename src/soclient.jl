struct SOError{T} <: Exception
    msg::T
end

struct SOClient
    ep::String
end

function SOClient(; ep = "https://api.stackexchange.com", api_version = "2.2")
    ep = ep * "/" * api_version * "/"
    SOClient(ep)
end

function process_response(response)
    headers = Dict(response.headers)
    if get(headers, "content-encoding", "") == "gzip"
        return response.body |> IOBuffer |> GzipDecompressorStream |> JSON3.read
    else
        # Do not know, what to do, let's throw an error
        @error "In searchtag response unknown encoding " * get(headers, "content-encoding", "\"empty field\"")
        throw(SOError("Not gzip encoded header: " * JSON3.write(headers)))
    end
end

function searchtag(client::SOClient; params...)
    params = Dict(params) |> HTTP.URIs.escapeuri
    url = client.ep * "search?"
    response = HTTP.get(url * params)

    return process_response(response)
end

function getquestions(client::SOClient, qids; params...)
    url = client.ep * "questions/"
    qids = join(qids, ";") |> HTTP.URIs.escapeuri
    params = Dict(params) |> HTTP.URIs.escapeuri

    response = HTTP.get(url * qids * "?" * params)

    return process_response(response)
end
