include("../../utilities/prelude.jl")

using Sockets

function eof_or_econnreset(socket)
    try
        eof(socket)
    catch err
        if !(err isa Base.IOError && err.code == Base.UV_ECONNRESET)
            rethrow(err)
        end
        true
    end
end

@testset "HMAC signing" begin
    server = QuartoNotebookRunner.serve()
    sock = Sockets.connect(server.port)

    wrong_key = Base.UUID(1234)

    command = Dict(
        :type => "run",
        :content =>
            abspath(joinpath(@__DIR__, "..", "..", "examples", "soft_scope.qmd")),
    )

    # check that an error is returned and no document has been run if the key is wrong
    QuartoNotebookRunner._write_hmac_json(sock, wrong_key, command)
    @test occursin("Incorrect HMAC digest", readline(sock))
    @test eof_or_econnreset(sock) # server closes upon receiving wrong hmac

    # reconnect
    sock = Sockets.connect(server.port)
    @test lock(server.notebookserver.lock) do
        isempty(server.notebookserver.workers)
    end

    # and that the opposite holds if the key is right
    QuartoNotebookRunner._write_hmac_json(sock, server.key, command)
    @test !occursin("Incorrect HMAC digest", readline(sock))
    @test lock(server.notebookserver.lock) do
        length(server.notebookserver.workers) == 1
    end

    QuartoNotebookRunner._write_hmac_json(
        sock,
        server.key,
        Dict(:type => "stop", :content => Dict()),
    )

    wait(server)
end
