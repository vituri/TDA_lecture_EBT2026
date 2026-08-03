# Checks the structural claim made on the "one knob at a time" and "two lenses"
# slides. Run it in a fresh process:
#
#     julia --project=. scripts/verify_layering.jl
#
# The claim. With a 1-D filter, every Mapper node is a cluster inside exactly one
# slice, and the clusters within a slice are disjoint — that is structural rather
# than a property of any one refiner: `Refiners.refine_cover` asks the refiner for
# one label per point and then forms `ids[findall(==(cl), labels)]`, so each point
# of a slice lands in exactly one cluster of it. Hence no edge ever joins two
# nodes of the same slice.
#
# `Uniform` places interval centres one step apart with radius (step/2)(1 +
# expansion), so slices i and i+2, which are two steps apart, intersect exactly
# when expansion > 1. Below that, every edge joins consecutive slices, so
#
#     node ↦ its slice index
#
# is a graph homomorphism onto a path. A path is bipartite and triangle-free, and
# both properties are inherited. Above expansion = 1 the shortcuts appear and the
# homomorphism is gone.
#
# expansion = 1 is the boundary: slices i and i+2 then share a single endpoint, so
# the claim survives only because no data point sits exactly there. The slides say
# `expansion < 1` and do not lean on that coincidence.
#
# With a 2-D grid cover the same argument targets the *king graph* on Z² — cells
# (i,j) and (i+1,j+1) overlap — which has triangles. So a 2-lens Mapper graph is
# not forced to be bipartite, and in practice is not.
#
# This file asserts all of that, so the slide cannot quietly go stale.

using CSV, DataFrames, MetricSpaces, MultivariateStats, Statistics, Graphs, Test
using TDAmapper, TDAmapper.ImageCovers, TDAmapper.IntervalCovers, TDAmapper.Refiners

include(joinpath(@__DIR__, "..", "..", "TDA_workshop_EBT2026", "scripts", "build_soccer_data.jl"))
players = CSV.read(build_soccer_data().output_path, DataFrame)

feature_cols = sort(filter(names(players)) do n
    startswith(String(n), "z_") &&
        !(n in ("z_goal_scoring_proxy", "z_playmaking_proxy", "z_defensive_proxy"))
end)
X = permutedims(Matrix(players[:, feature_cols]))
space = EuclideanSpace(X)
scores = predict(fit(PCA, X; maxoutdim = 2), X)
pc1, pc2 = vec(scores[1, :]), vec(scores[2, :])

ntriangles(g) = sum(Graphs.triangles(g)) ÷ 3

# The disjointness argument is about `refine_cover`, not about DBSCAN, so the
# consequence has to hold whichever refiner is used. Three quite different ones.
REFINERS = ("DBscan" => DBscan(radius = 2.5, min_cluster_size = 3),
    "FirstEmptyBin" => FirstEmptyBin(num_bins = 10),
    "Trivial" => Trivial())

results = NamedTuple[]
for (rname, R) in REFINERS
    println("── 1-D filter (PC1), 14 slices, refiner = $rname ──")
    for e in (0.2, 0.4, 0.8, 1.0, 1.2, 1.4, 2.0)
        g = classical_mapper(space, R1Cover(pc1, Uniform(length = 14, expansion = e)), R).g
        println("  expansion=$e  bipartite=$(is_bipartite(g))  triangles=$(ntriangles(g))  edges=$(ne(g))")
        push!(results, (refiner = rname, e = e, bip = is_bipartite(g), tri = ntriangles(g)))
    end
end

println("── 2-D lens (PC1, PC2), 12x12, refiner = DBscan ──")
two = map((0.4, 0.5)) do e
    C = R2Cover(collect(zip(pc1, pc2)),
        Uniform(length = 12, expansion = e), Uniform(length = 12, expansion = e))
    g = classical_mapper(space, C, DBscan(radius = 2.5, min_cluster_size = 3)).g
    println("  expansion=$e  bipartite=$(is_bipartite(g))  triangles=$(ntriangles(g))  edges=$(ne(g))")
    (e, is_bipartite(g), ntriangles(g))
end

@testset "layering" begin
    @testset "1-D filter, refiner = $(r.refiner), expansion = $(r.e)" for r in results
        if r.e < 1.0
            @test r.bip              # homomorphism onto a path ⇒ bipartite
            @test r.tri == 0         #                          ⇒ triangle-free
        elseif r.e > 1.0
            @test !r.bip             # shortcuts across slices break it
            @test r.tri > 0
        end
        # e == 1.0 is the boundary case and is deliberately not asserted.
    end
    @testset "2-D lens, expansion = $e" for (e, bip, tri) in two
        @test !bip                   # king graph on Z² has triangles
        @test tri > 0
    end
end
