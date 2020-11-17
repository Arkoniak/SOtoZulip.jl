struct ZulipClient
    ep::String
    headers::Vector{Pair{String, String}}
end

const ZulipGlobal = Ref(ZulipClient("", []))

function ZulipClient(; email = "", apikey = "", ep = "https://julialang.zulipchat.com", api_version = "v1")
    if isempty(email) || isempty(apikey)
        throw(ArgumentError("Arguments email and apikey should not be empty."))
    end

    key = base64encode(email * ":" * apikey)
    headers = ["Authorization" => "Basic " * key, "Content-Type" => "application/x-www-form-urlencoded"]
    endpoint = ep * "/api/" * api_version * "/"

    client = ZulipClient(endpoint, headers)

    return client
end

function global_zulip!(; email = "", apikey = "", ep = "https://julialang.zulipchat.com", api_version = "v1")
    client = ZulipClient(; email = email, apikey = apikey, ep = ep, api_version = api_version)
    ZulipGlobal[] = client
end

function query(client::ZulipClient, apimethod, params; method = "POST")
    params = HTTP.URIs.escapeuri(params)
    url = client.ep * apimethod
    JSON3.read(HTTP.request(method, url, client.headers, params).body)
end

function sendMessage(client::ZulipClient = ZulipGlobal[]; params...)
    query(client, "messages", Dict(params))
end

updateMessage(msg_id; params...) = updateMessage(ZulipGlobal[], msg_id; params...)
function updateMessage(client::ZulipClient, msg_id; params...)
    query(client, "messages/" * string(msg_id), Dict(params), method = "PATCH")
end

deleteMessage(msg_id; params...) = deleteMessage(ZulipGlobal[], msg_id; params...)
function deleteMessage(client::ZulipClient, msg_id; params...)
    query(client, "messages/" * string(msg_id), Dict(params), method = "DELETE")
end
