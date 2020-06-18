struct ZulipClient
    ep::String
    headers::Vector{Pair{String, String}}
end

mutable struct ZulipOpts
    client::ZulipClient
end

const ZulipGlobal = ZulipOpts(ZulipClient("", []))


function ZulipClient(; email = "", apikey = "", ep = "https://julialang.zulipchat.com", api_version = "v1", use_globally = true)
    if isempty(email) || isempty(apikey)
        throw(ArgumentError("Arguments email and apikey should not be empty."))
    end

    key = base64encode(email * ":" * apikey)
    headers = ["Authorization" => "Basic " * key, "Content-Type" => "application/x-www-form-urlencoded"]
    endpoint = ep * "/api/" * api_version * "/"

    client = ZulipClient(endpoint, headers)
    if use_globally
        ZulipGlobal.client = client
    end

    return client
end

function query(client::ZulipClient, apimethod, params; method = "POST")
    params = HTTP.URIs.escapeuri(params)
    url = client.ep * apimethod
    JSON3.read(HTTP.request(method, url, client.headers, params).body)
end

function sendMessage(client::ZulipClient = ZulipGlobal.client; params...)
    query(client, "messages", Dict(params))
end

updateMessage(msg_id; params...) = updateMessage(ZulipGlobal.client, msg_id; params...)
function updateMessage(client::ZulipClient, msg_id; params...)
    query(client, "messages/" * string(msg_id), Dict(params), method = "PATCH")
end
