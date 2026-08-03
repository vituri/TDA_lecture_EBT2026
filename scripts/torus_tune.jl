# Find a torus Mapper that is a clean cycle: every node degree 2, one component,
# one independent loop — so the figure matches the Reeb-graph claim exactly.

using Random, Statistics
using CSV, DataFrames, MetricSpaces, Graphs
using TDAmapper
using TDAmapper.ImageCovers, TDAmapper.IntervalCovers, TDAmapper.Refiners
using MetricSpaces.Datasets: torus

Random.seed!(20260724)

rows = DataFrame(n = Int[], len = Int[], exp = Float64[], ref = String[],
    nodes = Int[], edges = Int[], comps = Int[], loops = Int[],
    deg2 = Int[], tips = Int[], clean = Bool[])

for n in (2000, 4000), len in (10, 12, 14, 16), ex in (0.2, 0.3, 0.4, 0.5),
    (rname, R) in (("FEB10", FirstEmptyBin(num_bins = 10)),
                   ("FEB20", FirstEmptyBin(num_bins = 20)),
                   ("DB05", DBscan(radius = 0.5, min_cluster_size = 5)),
                   ("DB08", DBscan(radius = 0.8, min_cluster_size = 5)))

    X = torus(n) |> EuclideanSpace
    f = [x[1] for x in X]
    M = try
        classical_mapper(X, R1Cover(f, Uniform(length = len, expansion = ex)), R)
    catch
        continue
    end
    g = M.g
    d = degree(g)
    comps = length(connected_components(g))
    loops = ne(g) - nv(g) + comps
    push!(rows, (n, len, ex, rname, nv(g), ne(g), comps, loops,
        count(==(2), d), count(==(1), d), comps == 1 && loops == 1 && all(==(2), d)))
end

sort!(rows, [:clean, :loops], rev = true)
open(joinpath(@__DIR__, "..", "figures", "torus_sweep.txt"), "w") do io
    show(io, first(rows, 30); allrows = true, allcols = true)
end
println("clean cycles found: ", count(rows.clean))
show(first(rows[rows.clean, :], 10); allcols = true)
