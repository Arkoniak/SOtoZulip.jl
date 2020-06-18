struct ZulipClient
    ep::String
    headers::Vector{Pair{String, String}}
end

function ZulipClient(; email = "", apikey = "", ep = "https://julialang.zulipchat.com", api_version = "v1")
    if isempty(email) || isempty(apikey)
        throw(ArgumentError("Arguments email and apikey should not be empty."))
    else
        key = base64encode(email * ":" * apikey)
        headers = ["Authorization" => "Basic " * key, "Content-Type" => "application/x-www-form-urlencoded"]
        endpoint = ep * "/api/" * api_version * "/"
        return ZulipClient(endpoint, headers)
    end
end

function query(client::ZulipClient, apimethod, params, method = "POST")
    params = HTTP.URIs.escapeuri(params)
    url = client.ep * apimethod
    JSON3.read(HTTP.request(method, url, client.headers, params).body)
end

function sendMessage(client::ZulipClient; params...)
    query(client, "messages", Dict(params))
end
