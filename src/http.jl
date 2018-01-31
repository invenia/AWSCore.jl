#==============================================================================#
# http.jl
#
# HTTP Requests with retry/back-off and HTTPException.
#
# Copyright OC Technology Pty Ltd 2014 - All rights reserved
#==============================================================================#

import Base: show, UVError


http_status(e::HTTP.StatusError) = e.status
header(e::HTTP.StatusError, k, d="") = HTTP.header(e.response, k, d)
http_message(e::HTTP.StatusError) = String(e.response.body)
content_type(e::HTTP.StatusError) = HTTP.header(e.response, "Content-Type")

const http_stack = HTTP.stack(redirect=false, retry=false,
                              aws_authorization=false)

function http_request(request::AWSRequest)

    @repeat 4 try

        options = []
        if get(request, :return_stream, false)
            io = BufferStream()
            request[:response_stream] = io
            push!(options, (:response_stream, io))
        end

        return HTTP.request(http_stack,
                            request[:verb],
                            HTTP.URI(request[:url]),
                            HTTP.mkheaders(request[:headers]),
                            request[:content];
                            #aws_service = request[:service],
                            #aws_region = request[:region],
                            #aws_access_key_id = request[:creds].access_key_id,
                            #aws_secret_access_key = request[:creds].secret_key,
                            #aws_session_token = request[:creds].token,
                            verbose = debug_level - 1,
                            require_ssl_verification=false,
                            options...)

    catch e

        @delay_retry if isa(e, Base.DNSError) ||
                        isa(e, HTTP.ParsingError) ||
                        isa(e, HTTP.IOError) ||
                       (isa(e, HTTP.StatusError) && http_status(e) >= 500) end
    end

    assert(false) # Unreachable.
end


function http_get(url::String)

    host = HTTP.URI(url).host

    http_request(@SymDict(verb = "GET",
                          url = url,
                          headers = ["Host" => host],
                          content = UInt8[]))
end



#==============================================================================#
# End of file.
#==============================================================================#
