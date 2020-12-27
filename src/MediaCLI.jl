module MediaCLI
    include("transfer.jl")
    include("deflate.jl")

    export
            MediaConfig,
            Episode,
            Season,
            TVShow,
            transfer,
            deflate,
            discover_episodes,
            discover_seasons,
            plex_denomination
end
