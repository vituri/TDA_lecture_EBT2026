# Diagnostics-only search for the new soccer figures: filters, 2-lens covers,
# nerve thresholds and ball-mapper radii. Prints tables; writes no figures.
#
#     julia --project=. scripts/explore_soccer.jl > figures/explore.txt

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

X = permutedims(Matrix(players[:, feature_cols]))
space = EuclideanSpace(X)
n = length(space)

pc_scores = predict(fit(PCA, X; maxoutdim = 3), X)
pc1, pc2 = vec(pc_scores[1, :]), vec(pc_scores[2, :])

ecc = MetricSpaces.eccentricity(space)
dens = MetricSpaces.knn_density(space; k = 15)
attack = players.z_xg_per90 .+ players.z_xa_per90

labels = string.(players.position_group)
baseline = maximum(count(==(l), labels) for l in unique(labels)) / length(labels)
purity(M) = mean(map(ids -> (s = labels[ids]; maximum(count(==(l), s) for l in unique(s)) / length(s)), M.C))

function row(tag, M)
    g, d = M.g, degree(M.g)
    sizes = length.(M.C)
    @printf("%-38s nodes=%4d edges=%5d comp=%3d loops=%4d  tips=%3d branch=%3d iso=%3d  maxnode=%4d med=%5.1f  purity=%.3f\n",
        tag, nv(g), ne(g), length(connected_components(g)),
        ne(g) - nv(g) + length(connected_components(g)),
        count(==(1), d), count(>=(3), d), count(==(0), d),
        maximum(sizes), median(sizes), purity(M))
end

println("n=$n  features=$(length(feature_cols))  baseline purity=$(round(baseline, digits=3))")

# ── distance scale: needed to pick DBSCAN radii and ball-mapper epsilon ────────
Random.seed!(1)
sub = space[randperm(n)[1:600]]
D = [MetricSpaces.dist_euclidean(sub[i], sub[j]) for i in 1:600 for j in (i+1):600]
println("\npairwise distance quantiles (600-pt subsample):")
for q in (0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5)
    @printf("  q%-6.3f = %.3f\n", q, quantile(D, q))
end

# ── 1. one-dimensional filters ────────────────────────────────────────────────
println("\n══ 1-D filters ══")
for (fname, f) in (("pc1", pc1), ("ecc", ecc), ("dens", dens), ("attack", attack))
    for len in (14, 20, 30), exp in (0.4, 0.6), (rn, r, mc) in (("db2.0/3", 2.0, 3), ("db2.5/3", 2.5, 3))
        M = classical_mapper(space, R1Cover(f, Uniform(length = len, expansion = exp)),
            DBscan(radius = r, min_cluster_size = mc))
        row("$fname  U($len,$exp) $rn", M)
    end
end

# ── 2. two-dimensional lenses ─────────────────────────────────────────────────
println("\n══ 2-D lenses (R2Cover) ══")
for (lname, fa, fb) in (("pc1×ecc", pc1, ecc), ("pc1×pc2", pc1, pc2), ("ecc×attack", ecc, attack))
    for k in (8, 10, 12), exp in (0.4, 0.5), mc in (3, 5)
        f2 = collect(zip(fa, fb))
        M = classical_mapper(space, R2Cover(f2, Uniform(length = k, expansion = exp),
                Uniform(length = k, expansion = exp)),
            DBscan(radius = 2.5, min_cluster_size = mc))
        row("$lname  $(k)x$(k)($exp) mc=$mc", M)
    end
end

# ── 3. nerve thresholds on a dense 2-lens graph ────────────────────────────────
println("\n══ nerve thresholds (pc1×ecc 10x10, exp 0.5, mc=3) ══")
let f2 = collect(zip(pc1, ecc)),
    C = R2Cover(f2, Uniform(length = 10, expansion = 0.5), Uniform(length = 10, expansion = 0.5)),
    R = DBscan(radius = 2.5, min_cluster_size = 3)

    for (nname, N) in (("Simple", SimpleNerve()), ("MinCount(3)", MinCountNerve(3)),
        ("MinCount(5)", MinCountNerve(5)), ("Jaccard(0.05)", JaccardNerve(0.05)),
        ("Jaccard(0.1)", JaccardNerve(0.1)), ("Pct(0.15)", PercentageNerve(0.15)))
        row("nerve=$nname", classical_mapper(space, C, R, N))
    end
end

# ── 4. overlap past expansion = 1 breaks the layering ─────────────────────────
# radius = (step/2)(1+e); slices i and i+2 are 2*step apart, so they meet iff e > 1.
println("\n══ expansion sweep (pc1, 14 slices, DBscan(2.5,3)) — layering breaks at e>1 ══")
for exp in (0.2, 0.4, 0.8, 1.0, 1.4, 2.0)
    M = classical_mapper(space, R1Cover(pc1, Uniform(length = 14, expansion = exp)),
        DBscan(radius = 2.5, min_cluster_size = 3))
    row("pc1  U(14, $exp)", M)
end

# ── 5. ball mapper: landmark count × radius ────────────────────────────────────
println("\n══ ball mapper ══")
for nl in (80, 120, 200)
    Random.seed!(20260724)
    L = farthest_points_sample_ids(space, nl)
    for eps in (2.5, 3.0, 3.5, 4.0)
        row("ball  L=$nl eps=$eps", ball_mapper(space, L, eps))
    end
end
