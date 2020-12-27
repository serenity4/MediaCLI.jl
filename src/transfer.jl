struct MediaConfig
    series_path::String
    movies_path::String
end

struct Episode
    number::Union{Int,UnitRange}
    location::String
end

struct Season
    number::Int
    episodes::Vector{Episode}
end

struct TVShow
    name::String
    seasons::Vector{Season}
end

padded(x::Number) = lpad(x, 2, '0')

plex_denomination(ep::Episode) = join(["e"] .* padded.(collect(ep.number)), "-")
plex_denomination(s::Season, is_dir::Bool = false) = string(is_dir ? "Season " : "s", padded(s.number))
plex_denomination(s::Season, ep::Episode) = string(plex_denomination(s), plex_denomination(ep))
plex_denomination(show::TVShow, s::Season, ep::Episode) = string(show.name, " - ", plex_denomination(s, ep))


Base.:(==)(x::Season, y::Season) = x.number == y.number && length(x.episodes) == length(y.episodes) && all(x.episodes .== y.episodes)

Season(number::Int, location::AbstractString) = Season(number, location, 1)
Season(number::Int, locations::Vector{<:AbstractString}, args...) = Season(number, locations[number], args...)

function transfer(config::MediaConfig, show::TVShow; dest=nothing, force::Bool=false, confirm::Bool=true)
    dest = isnothing(dest) ? joinpath(config.series_path, show.name) : dest
    transfer(show, dest; force, confirm)
end

transfer(show::TVShow, dest::AbstractString; force::Bool=false, confirm::Bool=true) = map(x -> transfer(show, x, dest; force, confirm), show.seasons)

function transfer(src::AbstractString, dest::AbstractString; force::Bool=false)
    if force || src ≠ dest
        mv(src, dest; force)
    else
        @warn "Ignored existing destination $dest. Set 'force' to true to replace."
    end
end

function discover_seasons(name::AbstractString, src::AbstractString)
    name_parts = lowercase.(filter(x -> !isnothing(match(r"^\w+$", x)), split(basename(name), ['.', ' ', '_', '-'])))
    season_dirs = filter(x -> all(occursin(part, lowercase(x)) for part ∈ name_parts) && isdir(x), readdir(src, join=true))
    matches = filter(x -> !isnothing(x.first), map(x -> match(r"(?:Season\W*|Saison\W*|S|s)(\d{1,2})", x) => x, season_dirs))
    map(x -> Season(parse(Int, x.first.captures[1]), discover_episodes(x.second)), matches)
end

const ignored_extensions = [".jl", ".srt", ".jpeg", ".png", ".jpg", ".bmp"]

function discover_episodes(src::AbstractString)::Vector{Episode}
    episode_candidates = filter(!isnothing, find_media.(readdir(src, join=true)))
    matches = filter(x -> !isnothing(x.first), map(x -> something(match(r"\/(\d+)\s\-\s[\dA-Z]", x), match(r"(?:s|S)\d{2}(?:\-|x|e|E)(\d{2})", x), Some(nothing)) => x, episode_candidates))
    map(x -> Episode(parse(Int, x.first.captures[1]), x.second), matches)
end

function find_media(src::AbstractString)
    if isfile(src)
        last(splitext(src)) ∉ ignored_extensions && stat(src).size > 50e6 && return src # filesize more than 50 MB
        nothing
    elseif isdir(src)
        medias = filter(!isnothing, find_media.(readdir(src, join=true)))
        if length(medias) > 1
            @warn "Found more than one candidate while searching for an episode. Taking the bigger candidate.\nCandidates found: $medias"
        end
        if !isempty(medias)
            medias[argmax(stat.(medias))]
        else
            nothing
        end
    else
        nothing
    end
end

function transfer(show::TVShow, season::Season, dest::AbstractString; force::Bool=false, confirm::Bool=true)
    source_files = getproperty.(season.episodes, :location)
    pardirs = unique(dirname.(source_files))
    dest = joinpath(dest, plex_denomination(season, true))
    dest ∈ pardirs && error("Source and destination folders are the same for a non-copying transfer operation.")

    dests = map(x -> joinpath(dest, string(plex_denomination(show, season, x), last(splitext(x.location)))), season.episodes)

    printstyled(show.name, " ", bold=true, color=:yellow)
    printstyled(plex_denomination(season, true), bold=false, color=:yellow)
    println()
    show_transfer_recap.(source_files, dests)

    n = length(source_files)

    if n == 0
        @info "No files found for transfer."
        return
    end

    if length(pardirs) == 1
        @info "$n files ready for transfer from \"$(first(pardirs))\" to \"$dest\""
    else
        @info "$n files ready for transfer from multiple sources to \"$dest\""
    end

    if confirm
        @warn "The files will be moved to the new destination. Continue? (Y/n)"
        await_confirmation(true) || return
    end

    mkpath(dest)
    transfer.(source_files, dests; force)
    @info "Transfer successful."
end

show_transfer_recap(src::AbstractString, dst::AbstractString; padding=70) = begin
    printstyled(src, color=:red)
    printstyled(" ", rpad("=>", padding - length(src) - 1, '='), " ")
    printstyled(dst, color=:green)
    println()
end

function await_confirmation(default)
    try
        while true
            answer = strip(readline(), [' ', '\n'])
            if isempty(answer) && !isnothing(default)
                return default
            elseif lowercase(answer) ∉ ["y", "n"]
                println("Answer not understood. Transfer files? (y/n)")
            elseif answer == "y"
                return true
            else
                @info "Operation aborted."
                return false
            end
            default = nothing
        end
    catch e
        if e isa InterruptException
            @info "Operation aborted."
            exit(0)
        else
            rethrow(e)
        end
    end
end
