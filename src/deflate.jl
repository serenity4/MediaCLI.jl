isvideo(file) = any(endswith.(Ref(file), [".mkv", ".avi"])) && stat(file).size / 10^9 > 0.2 # consider that a file > 200 MB is a video file

function deflate(source, pattern; dest="deflated")
    run(`mkdir -p $dest`)
    for el ∈ readdir(source, join=true)
        if isdir(el) && !isnothing(match(pattern, el))
            for file ∈ readdir(el, join=false)
                file_joined = joinpath(el, file)
                if isvideo(file_joined)
                    mv(file_joined, joinpath(dest, file))
                end
            end
        end
    end
end

