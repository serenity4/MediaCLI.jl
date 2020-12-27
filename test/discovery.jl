show_name = "Stargate SG-1"
show_dir = joinpath(tempdir(), show_name)
episodes = joinpath.(show_dir, [joinpath("Season $i", "$show_name - s$(i)e$(e).mkv") for i ∈ lpad.(1:10, 2, '0'), e ∈ lpad.(1:20, 2, '0')])
mkpath.(dirname.(episodes))
touch.(episodes)

@testset "Discovery" begin
    @testset "Episodes" begin
        @test all(discover_episodes(dirname(episodes[1, 1])) .== Episode.(1:20, episodes[1, :]))
        @test all(discover_seasons(show_name, show_dir) .== [Season(i, Episode.(1:20, episodes[i, :])) for i ∈ 1:10])
    end
end
