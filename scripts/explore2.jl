# Second pass: narrow in on the eccentricity "flare" config and the ball-mapper
# radius window. Diagnostics only.

using Random, Statistics, Printf
using CSV, DataFrames, MetricSpaces, MultivariateStats, Graphs
using TDAmapper
using TDAmapper.ImageCovers, TDAmapper.IntervalCovers, TDAmapper.Refiners, TDAmapper.Nerves

include(joinpath(@__DIR__, "..", "..", "TDA_workshop_EBT2026", "scripts", "build_soccer_data.jl"))
players = CSV.read(build_soccer_data().output_path, DataFrame)

feature_cols = sort(filter(names(players)) do name
    startswith(String(name), "z_") &&
        !(name in ("z_goal_scoring_proxy", "z_playmaking_proxy", "z_defensive_proxy"))
end)
space = EuclideanSpace(permutedims(Matrix(players[:, feature_cols])))
labels = string.(players.position_group)
purity(M) = mean(map(ids -> (s = labels[ids]; maximum(count(==(l), s) for l in unique(s)) / length(s)), M.C))

function row(tag, M)
    g, d = M.g, degree(M.g)
    s = length.(M.C)
    @printf("%-34s nodes=%4d edges=%5d comp=%3d loops=%4d tips=%3d branch=%3d iso=%3d maxnode=%4d med=%5.1f pur=%.3f\n",
        tag, nv(g), ne(g), length(connected_components(g)), ne(g)-nv(g)+length(connected_components(g)),
        count(==(1), d), count(>=(3), d), count(==(0), d), maximum(s), median(s), purity(M))
end

ecc = MetricSpaces.eccentricity(space)

println("══ eccentricity: maximise tips, minimise components ══")
for len in (18, 20, 22, 24, 26), exp in (0.5, 0.6, 0.8), (r, mc) in ((2.0, 3), (2.0, 4), (2.2, 3), (2.2, 4))
    M = classical_mapper(space, R1Cover(ecc, Uniform(length = len, expansion = exp)),
        DBscan(radius = r, min_cluster_size = mc))
    row("ecc U($len,$exp) db$r/$mc", M)
end

println("\n══ ball mapper: the radius window, L = 100 landmarks ══")
Random.seed!(20260724)
L = farthest_points_sample_ids(space, 100)
for eps in (2.8, 3.0, 3.1, 3.2, 3.3, 3.4, 3.6)
    row("ball L=100 eps=$eps", ball_mapper(space, L, eps))
end

println("\n══ ball mapper: epsilon_net landmarks (covering guarantee) ══")
for eps in (3.0, 3.2, 3.5)
    Lnet = epsilon_net(space, eps)
    print("eps=$eps  |L|=$(length(Lnet))  ")
    row("ball net eps=$eps", ball_mapper(space, Lnet, eps))
end
