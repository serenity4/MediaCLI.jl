using MediaCLI
using ArgParse

function parse_cli()
    s = ArgParseSettings()
    @add_arg_table s begin
        "transfer"
            help = "transfer files to a media storage with Plex naming conventions"
            action = :command
        "deflate"
            help = "extract video files from individual folders matching the given pattern and puts them into a separate folder"
            action = :command
    end

    @add_arg_table! s["transfer"] begin
        "name"
            help = "tv show name"
            required = true
            arg_type = String
        "-s", "--seasons"
            help = "seasons"
            arg_type = String
            default = "1"
        "--source"
            help = "source files path. Must be the folder containing the season folders."
            default = pwd()
        "-n", "--no-confirm"
            help = "do not prompt user for confirmation before transfering files"
            action = :store_true
        "-m", "--media-storage"
            help = "location where to store the media"
            default = "/media/belmant/WD Elements"
    end

    @add_arg_table s["deflate"] begin
        "path"
            help = "path where to look for individual folders"
            arg_type = String
        "pattern"
            help = "regular expression whose matches are considered individual folders"
            arg_type = Regex
        "-d", "--dest"
            help = "path where to store the extracted videos"
            arg_type = String
            default = "deflated"
    end

    parse_args(s)
end

function print_cli(args)
    println("CLI parameters")
    for (k, v) ∈ args
        println("   $k: $v")
    end
end

function parse_season_spec(spec::AbstractString, season_dirs::Vector{<:AbstractString})
    spec_split_slash = split(spec, '/')
    if length(spec_split_slash) == 2
        spec, begin_at_str = spec_split_slash
    else
        begin_at_str = "1"
    end
    begin_at = parse(Int, begin_at_str)

    spec_split_colon = split(spec, ':')
    if length(spec_split_colon) == 2
        is = UnitRange(parse.(Int, spec_split_colon)...)
        return map(i -> Season(i, season_dirs, begin_at), is)
    end

    Season(parse(Int, spec), season_dirs, begin_at)
end

function MediaCLI.transfer(args::AbstractDict)
    media = MediaConfig(joinpath.(args["media-storage"], ["Series", "Movies"])...)
    src = args["source"]
    season_dirs = filter(isdir, readdir(src, join=true))
    # show = TVShow(args["name"], vcat(map(x -> parse_season_spec(x, season_dirs), split(args["seasons"]))...))
    show = TVShow(args["name"], discover_seasons(args["name"], src))
    confirm = !(args["no-confirm"])
    transfer(media, show; confirm)
end

function MediaCLI.deflate(args::AbstractDict)
    path, pattern, dest = args["path"], args["pattern"], args["dest"]
    deflate(path, pattern; dest)
end

Base.exit_on_sigint(false)

args = parse_cli()

f = getproperty(MediaCLI, Symbol(args["%COMMAND%"]))

cmd_args = args[args["%COMMAND%"]]

print_cli(cmd_args)

f(cmd_args)
