# Generate the rotating point clouds and Mapper graphs used by the filter slides.
#
# Run from TDA_lecture_EBT2026:
#
#     julia --project=. scripts/make_filter_figures.jl
#
# The flamingo source has 26,907 points.  Mapper is deliberately computed on one
# fixed 2,400-point farthest-point sample (`farthest_points_sample_ids`) so that
# regenerating the comparison remains quick without concentrating points in the
# densest parts of the scan.

using Random
using Downloads
using SparseArrays
using CSV, DataFrames, MetricSpaces, Statistics, Graphs
using Clustering
using CairoMakie
using TDAmapper
using TDAmapper.ImageCovers, TDAmapper.IntervalCovers, TDAmapper.Refiners
using TDAplots
using MetricSpaces.Datasets: torus

isdefined(Main, :graph_plot) || include(joinpath(@__DIR__, "mapper_draw.jl"))

const FILTER_FIGDIR = normpath(joinpath(@__DIR__, "..", "figures"))
const FILTER_DATADIR = normpath(joinpath(@__DIR__, "..", "data"))
const FLAMINGO_SAMPLE = joinpath(FILTER_DATADIR, "flamingo_sample.csv")
const FLAMINGO_SAMPLE_META = joinpath(FILTER_DATADIR, "flamingo_sample.meta")
const FLAMINGO_URL =
    "https://raw.githubusercontent.com/vituri/mapperGUI/master/examples/flam-reference.csv"

function load_flamingo_sample(; n = 2400, seed = 20260802)
    signature = "method=farthest_points_sample_ids\nn=$n\nseed=$seed\nsource=$FLAMINGO_URL\n"
    if isfile(FLAMINGO_SAMPLE) && isfile(FLAMINGO_SAMPLE_META) &&
        read(FLAMINGO_SAMPLE_META, String) == signature
        sample = Matrix{Float64}(CSV.read(FLAMINGO_SAMPLE, DataFrame))
        size(sample, 1) == n && return sample
    end

    mkpath(FILTER_DATADIR)
    source_path = Downloads.download(FLAMINGO_URL)
    full = Matrix{Float64}(CSV.read(source_path, DataFrame; header = false))
    n <= size(full, 1) || error("sample size $n exceeds $(size(full, 1)) source points")

    Random.seed!(seed)
    ids = farthest_points_sample_ids(
        EuclideanSpace(permutedims(full)), n; show_progress = true)
    sample = full[ids, :]
    CSV.write(FLAMINGO_SAMPLE, DataFrame(x = sample[:, 1], y = sample[:, 2], z = sample[:, 3]))
    open(FLAMINGO_SAMPLE_META, "w") do io
        write(io, signature)
    end
    println("wrote data/flamingo_sample.csv ($n-point farthest-point sample " *
        "from $(size(full, 1)) points)")
    return sample
end

function rotate_points(points, pivot, axis, angle)
    c, s = cos(angle), sin(angle)
    R = if axis == :x
        [1.0 0.0 0.0; 0.0 c -s; 0.0 s c]
    elseif axis == :y
        [c 0.0 s; 0.0 1.0 0.0; -s 0.0 c]
    elseif axis == :z
        [c -s 0.0; s c 0.0; 0.0 0.0 1.0]
    else
        error("rotation axis must be :x, :y, or :z")
    end
    return (points .- permutedims(pivot)) * transpose(R) .+ permutedims(pivot)
end

point3f_rows(points) = [Point3f(p[1], p[2], p[3]) for p in eachrow(points)]

function edge_segments(points, graph)
    segments = Point3f[]
    sizehint!(segments, 2 * ne(graph))
    for edge in edges(graph)
        push!(segments,
            Point3f(points[src(edge), 1], points[src(edge), 2], points[src(edge), 3]),
            Point3f(points[dst(edge), 1], points[dst(edge), 2], points[dst(edge), 3]))
    end
    return segments
end

function rotation_limits(points, pivot, axis; padding = 1.08)
    centered = points .- permutedims(pivot)
    if axis == :y
        radius = padding * maximum(hypot.(centered[:, 1], centered[:, 3]))
        ymin, ymax = extrema(points[:, 2])
        margin = 0.04 * max(ymax - ymin, 2radius)
        return (pivot[1] - radius, pivot[1] + radius,
            ymin - margin, ymax + margin,
            pivot[3] - radius, pivot[3] + radius)
    elseif axis == :z
        radius = padding * maximum(hypot.(centered[:, 1], centered[:, 2]))
        zmin, zmax = extrema(points[:, 3])
        margin = 0.04 * max(zmax - zmin, 2radius)
        return (pivot[1] - radius, pivot[1] + radius,
            pivot[2] - radius, pivot[2] + radius,
            zmin - margin, zmax + margin)
    end
    radius = padding * maximum(hypot.(centered[:, 2], centered[:, 3]))
    xmin, xmax = extrema(points[:, 1])
    margin = 0.04 * max(xmax - xmin, 2radius)
    return (xmin - margin, xmax + margin,
        pivot[2] - radius, pivot[2] + radius,
        pivot[3] - radius, pivot[3] + radius)
end

function rotating_cloud(path, points, values;
    markersize = 4.2,
    elevation = 0.30,
    camera_azimuth = -0.50pi,
    rotation_axis = :z,
    pivot = vec(mean(points; dims = 1)),
    nframes = 60,
    framerate = 12,
    graph = nothing,
    ground = false,
)
    value_range = extrema(values)
    fig = Figure(size = (520, 520), backgroundcolor = :white, figure_padding = 2)
    ax = Axis3(fig[1, 1];
        aspect = :data,
        azimuth = camera_azimuth,
        elevation = elevation,
        perspectiveness = 0.58,
        viewmode = :fit,
        limits = rotation_limits(points, pivot, rotation_axis),
    )

    animated_points = Observable(point3f_rows(points))
    animated_edges = isnothing(graph) ? nothing : Observable(edge_segments(points, graph))
    if !isnothing(animated_edges)
        linesegments!(ax, animated_edges; color = (:gray20, 0.45), linewidth = 0.65)
    end
    if ground
        radius = 0.16 * (maximum(points[:, 3]) - minimum(points[:, 3]))
        circle = [Point3f(pivot[1] + radius * cos(t), pivot[2] + radius * sin(t), 0)
                  for t in range(0, 2pi; length = 100)]
        lines!(ax, circle; color = (:gray45, 0.35), linewidth = 1.2)
    end
    scatter!(ax, animated_points;
        color = values,
        colorrange = value_range,
        colormap = :viridis,
        markersize = markersize,
    )
    hidedecorations!(ax)
    hidespines!(ax)

    angles = range(0, 2pi; length = nframes + 1)[1:end-1]
    record(fig, path, angles; framerate = framerate) do angle
        rotated = rotate_points(points, pivot, rotation_axis, angle)
        animated_points[] = point3f_rows(rotated)
        isnothing(animated_edges) || (animated_edges[] = edge_segments(rotated, graph))
    end
    println("wrote $(basename(path))")
end

function flamingo_for_display(points)
    # In the source cloud y is the physical vertical axis.  Put the lowest feet
    # on z=0 and use their centroid as the turntable axis.
    floor_y = minimum(points[:, 2])
    cutoff = quantile(points[:, 2], 0.015)
    foot_ids = findall(<=(cutoff), points[:, 2])
    foot_x = mean(points[foot_ids, 1])
    foot_depth = mean(points[foot_ids, 3])
    return hcat(points[:, 1] .- foot_x,
        points[:, 3] .- foot_depth,
        points[:, 2] .- floor_y)
end

function foot_groups(points; floor_fraction = 0.05)
    # The two feet form the two x-separated components of the bottom 5% of the
    # sample.  Splitting at the largest x-gap avoids baking in a point index or
    # a coordinate threshold specific to this sample.
    floor_y = quantile(points[:, 2], floor_fraction)
    floor_ids = findall(<=(floor_y), points[:, 2])
    ordered = sort(floor_ids; by = i -> points[i, 1])
    split_at = argmax(diff(points[ordered, 1]))
    left = Set(ordered[1:split_at])
    right = Set(ordered[(split_at + 1):end])
    isempty(left) && error("could not identify the left foot")
    isempty(right) && error("could not identify the right foot")
    return left, right
end

crosses_feet(i, j, feet) =
    (i in feet[1] && j in feet[2]) || (i in feet[2] && j in feet[1])

function knn_graph(space; k = 6, disconnected_groups = nothing)
    graph = SimpleGraph(length(space))
    weights = spzeros(Float64, length(space), length(space))
    for i in eachindex(space)
        for j in MetricSpaces.k_neighbors_ids(space, space[i], k + 1)
            i == j && continue
            isnothing(disconnected_groups) ||
                !crosses_feet(i, j, disconnected_groups) || continue
            add_edge!(graph, i, j)
            weight = Float64(MetricSpaces.dist_euclidean(space[i], space[j]))
            weights[i, j] = weight
            weights[j, i] = weight
        end
    end
    is_connected(graph) || error("the $k-NN graph is disconnected")
    return graph, weights
end

function graph_distance_matrix(graph, weights)
    distances = Matrix{Float64}(undef, nv(graph), nv(graph))
    for source in vertices(graph)
        distances[source, :] .= dijkstra_shortest_paths(graph, source, weights).dists
    end
    return distances
end

struct GeodesicDBscan{T} <: AbstractRefiner
    point_ids::Dict{NTuple{3,T},Int}
    distances::Matrix{Float64}
    radius::Float64
    min_neighbors::Int
    min_cluster_size::Int
end

function GeodesicDBscan(space, distances;
    radius = 0.1, min_neighbors = 1, min_cluster_size = 1)
    point_ids = Dict(Tuple(point) => i for (i, point) in enumerate(space))
    T = eltype(first(space))
    return GeodesicDBscan{T}(
        point_ids, distances, radius, min_neighbors, min_cluster_size)
end

function (refiner::GeodesicDBscan)(subset::MetricSpace)
    length(subset) == 1 && return ones(Int, 1)
    ids = [refiner.point_ids[Tuple(point)] for point in subset]
    assignments = Clustering.dbscan(
        refiner.distances[ids, ids], refiner.radius;
        metric = nothing,
        min_neighbors = refiner.min_neighbors,
        min_cluster_size = refiner.min_cluster_size,
    ).assignments
    return create_outlier_cluster(assignments)
end

function closest_pair(points, left, right)
    best = (left = 0, right = 0, distance = Inf)
    for i in left, j in right
        distance = sqrt(sum(abs2, points[i, :] - points[j, :]))
        distance < best.distance && (best = (left = i, right = j, distance = distance))
    end
    return best
end


function mixed_foot_nodes(mapper, feet)
    return [i for (i, node) in enumerate(mapper.C)
        if !isdisjoint(node, feet[1]) && !isdisjoint(node, feet[2])]
end

function mapper_summary(M)
    components = length(connected_components(M.g))
    return (
        nodes = nv(M.g),
        edges = ne(M.g),
        components = components,
        cycle_rank = ne(M.g) - nv(M.g) + components,
    )
end

function make_filter_figures()
    mkpath(FILTER_FIGDIR)

    # Torus: colour by projection onto x and rotate the object about y.
    Random.seed!(20260724)
    torus_points = reduce(vcat, permutedims.(torus(4000)))
    torus_values = torus_points[:, 1]
    rotating_cloud(joinpath(FILTER_FIGDIR, "torus_x.gif"),
        torus_points, torus_values;
        markersize = 3.0,
        elevation = 0.28,
        camera_azimuth = 1.22pi,
        rotation_axis = :y,
        nframes = 60,
        framerate = 10,
    )

    torus_space = EuclideanSpace(permutedims(torus_points))
    torus_mapper = classical_mapper(torus_space,
        R1Cover(torus_values, Uniform(length = 8, expansion = 0.3)),
        DBscan(radius = 0.8, min_cluster_size = 5))
    torus_node_values = node_colors(torus_mapper, torus_values)
    torus_figure = mapper_plot(torus_mapper;
        node_positions = layout_torus_reeb(torus_mapper, torus_node_values),
        node_size = node_sizes(torus_mapper; area_max = 28),
        node_values = torus_node_values,
        edge_size = 1.5)
    # Keep the loop narrow and centered, like the standard torus Reeb-graph
    # schematic, instead of stretching it across the full rectangular panel.
    torus_axis = only(filter(x -> x isa Axis, torus_figure.content))
    limits!(torus_axis, -1.05, 1.05, -1.12, 1.12)
    save(joinpath(FILTER_FIGDIR, "torus_mapper.png"), torus_figure; px_per_unit = 2)
    println("wrote torus_mapper.png")

    flamingo = load_flamingo_sample()
    space = EuclideanSpace(permutedims(flamingo))
    flamingo_display = flamingo_for_display(flamingo)

    # The tip with largest longitudinal coordinate is a reproducible beak
    # landmark; no manual point index is baked into the presentation.
    beak_id = argmax(flamingo[:, 2])
    beak = flamingo[beak_id, :]
    feet = foot_groups(flamingo)
    neighbor_graph, neighbor_weights = knn_graph(
        space; k = 3, disconnected_groups = feet)
    cross_foot_edges = count(e -> crosses_feet(src(e), dst(e), feet), edges(neighbor_graph))
    cross_foot_edges == 0 || error("the two feet are directly connected in the k-NN graph")

    # Eccentricity with the graph geodesic as its metric: every point is
    # coloured by its mean shortest-path distance to the whole sample.
    geodesic_distances = graph_distance_matrix(neighbor_graph, neighbor_weights)
    all(isfinite, geodesic_distances) || error("geodesic distance matrix contains Inf")
    geodesic_values = vec(mean(geodesic_distances; dims = 2))
    nearest_feet = closest_pair(flamingo, feet...)
    nearest_feet_geodesic = geodesic_distances[nearest_feet.left, nearest_feet.right]
    filters = (
        (tag = "height", label = "height y", values = flamingo[:, 2],
            show_graph = false, intrinsic = false),
        (tag = "beak", label = "distance from the beak",
            values = vec(sqrt.(sum((flamingo .- reshape(beak, 1, 3)) .^ 2; dims = 2))),
            show_graph = false, intrinsic = false),
        (tag = "eccentricity", label = "eccentricity",
            values = MetricSpaces.eccentricity(space), show_graph = false, intrinsic = false),
        (tag = "geodesic", label = "eccentricity with geodesic distance",
            values = geodesic_values, show_graph = true, intrinsic = true),
    )

    # The cover and DBSCAN scale stay fixed.  The geodesic panel also uses the
    # graph metric for clustering; otherwise ambient DBSCAN glues the feet even
    # when the filter itself is intrinsic.
    cover = Uniform(length = 14, expansion = 0.4)
    euclidean_refiner = DBscan(radius = 0.06, min_cluster_size = 5)
    geodesic_refiner = GeodesicDBscan(
        space, geodesic_distances; radius = 0.06, min_cluster_size = 5)
    summaries = Dict{String,Any}()
    mixed_feet = Dict{String,Vector{Int}}()

    for spec in filters
        rotating_cloud(joinpath(FILTER_FIGDIR, "flamingo_$(spec.tag).gif"),
            flamingo_display, spec.values;
            markersize = spec.show_graph ? 3.5 : 4.4,
            elevation = 0.08,
            camera_azimuth = -0.50pi,
            rotation_axis = :z,
            pivot = zeros(3),
            nframes = 60,
            framerate = 12,
            graph = spec.show_graph ? neighbor_graph : nothing,
            ground = true,
        )

        refiner = spec.intrinsic ? geodesic_refiner : euclidean_refiner
        mapper = classical_mapper(space, R1Cover(spec.values, cover), refiner)
        mixed_feet[spec.tag] = mixed_foot_nodes(mapper, feet)
        spec.intrinsic && !isempty(mixed_feet[spec.tag]) &&
            error("geodesic Mapper contains mixed-foot nodes: $(mixed_feet[spec.tag])")
        Random.seed!(20260802)
        fig = graph_plot(mapper;
            positions = layout_packed(mapper; seed = 20260802, aspect = 1.0),
            sizes = node_sizes(mapper; area_max = 28),
            node_values = node_colors(mapper, spec.values),
            colormap = :viridis,
            figsize = (620, 560),
        )
        save(joinpath(FILTER_FIGDIR, "flamingo_$(spec.tag)_mapper.png"), fig; px_per_unit = 2)
        println("wrote flamingo_$(spec.tag)_mapper.png")
        summaries[spec.tag] = mapper_summary(mapper)
    end

    open(joinpath(FILTER_FIGDIR, "flamingo_stats.txt"), "w") do io
        println(io, "source = $FLAMINGO_URL")
        println(io, "sample = $(size(flamingo, 1)) / 26907 points " *
            "(farthest_points_sample_ids, seed 20260802)")
        println(io, "cover = Uniform(length=14, expansion=0.4)")
        println(io, "refiner = DBscan(radius=0.06, min_cluster_size=5); " *
            "Euclidean metric for filters 1-3, graph-geodesic metric for filter 4")
        println(io, "geodesic eccentricity = mean all-pairs shortest-path distance on " *
            "a 3-NN graph ($(ne(neighbor_graph)) edges), Euclidean edge weights")
        println(io, "cross-foot edges = $cross_foot_edges")
        println(io, "mixed-foot nodes in geodesic Mapper = $(length(mixed_feet["geodesic"]))")
        println(io, "closest opposing-foot points = " *
            "Euclidean $(round(nearest_feet.distance; digits = 3)), " *
            "geodesic $(round(nearest_feet_geodesic; digits = 3)), " *
            "ratio $(round(nearest_feet_geodesic / nearest_feet.distance; digits = 1))x")
        ts = mapper_summary(torus_mapper)
        println(io, "torus-x: nodes=$(ts.nodes) edges=$(ts.edges) " *
            "components=$(ts.components) cycle_rank=$(ts.cycle_rank)")
        for spec in filters
            s = summaries[spec.tag]
            println(io, "$(spec.tag): nodes=$(s.nodes) edges=$(s.edges) " *
                "components=$(s.components) cycle_rank=$(s.cycle_rank)")
        end
    end
    println("wrote flamingo_stats.txt")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && make_filter_figures()
