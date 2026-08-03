# Parameter sweep: find a (filter, cover, refiner) with genuine branching, i.e.
# a backbone with flares, rather than the path the PC1 default produces.

using CSV, DataFrames, MetricSpaces, MultivariateStats, Statistics, Graphs
using TDAmapper
using TDAmapper.ImageCovers, TDAmapper.IntervalCovers, TDAmapper.Refiners

include(joinpath(@__DIR__, "..", "..", "TDA_workshop_EBT2026", "scripts", "build_soccer_data.jl"))
players = CSV.read(build_soccer_data().output_path, DataFrame)

feature_cols = sort(filter(names(players)) do n
    startswith(String(n), "z_") &&
        !(n in ("z_goal_scoring_proxy", "z_playmaking_proxy", "z_defensive_proxy"))
end)

X = permutedims(Matrix(players[:, feature_cols]))
space = EuclideanSpace(X)

pc = predict(fit(PCA, X; maxoutdim = 2), X)
filters = Dict(
    "pc1"     => vec(pc[1, :]),
    "ecc"     => MetricSpaces.eccentricity(space),
    "density" => MetricSpaces.knn_density(space; k = 15),
)

refiners = Dict(
    "FEB10"  => FirstEmptyBin(num_bins = 10),
    "FEB20"  => FirstEmptyBin(num_bins = 20),
    "DB2"    => DBscan(radius = 2.0, min_cluster_size = 3),
    "DB3"    => DBscan(radius = 3.0, min_cluster_size = 3),
    "DB4"    => DBscan(radius = 4.0, min_cluster_size = 3),
    "SL2"    => Hierarchical(linkage = :single, threshold = 2.0),
    "SL3"    => Hierarchical(linkage = :single, threshold = 3.0),
)

rows = DataFrame(filter = String[], refiner = String[], len = Int[], exp = Float64[],
    nodes = Int[], edges = Int[], comps = Int[],
    tips = Int[], branch = Int[], singles = Int[], biggest = Int[])

for (fname, fv) in filters, (rname, R) in refiners,
    len in (10, 14, 18), ex in (0.3, 0.5)

    M = try
        classical_mapper(space, R1Cover(fv, Uniform(length = len, expansion = ex)), R)
    catch
        continue
    end
    g = M.g
    nv(g) == 0 && continue
    d = degree(g)
    sizes = length.(M.C)
    push!(rows, (fname, rname, len, ex, nv(g), ne(g),
        length(connected_components(g)),
        count(==(1), d), count(>=(3), d), count(x -> x <= 2, sizes),
        maximum(sizes)))
end

# "Interesting" = has branch points, several flare tips, mostly one component,
# and not dominated by junk singletons.
rows.score = @. rows.branch * 2 + rows.tips - rows.comps - rows.singles

sort!(rows, :score, rev = true)
open(joinpath(@__DIR__, "..", "figures", "sweep.txt"), "w") do io
    show(io, first(rows, 40); allcols = true, allrows = true)
    println(io, "\n\n── configs with >=2 branch points, <=2 components ──")
    good = rows[(rows.branch .>= 2) .& (rows.comps .<= 2), :]
    show(io, first(good, 25); allcols = true, allrows = true)
end
println("wrote sweep.txt")
show(first(rows, 20); allcols = true)
