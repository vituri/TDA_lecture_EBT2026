# Generate the two worked examples for the differentiable-Mapper slides.
#
# Run from TDA_lecture_EBT2026:
#
#     julia --project=. scripts/make_differentiable_figures.jl
#
# The topological loss is label-free.  Shape-part and football-position labels
# are used only after optimization, to evaluate the resulting representations.

using Random
using LinearAlgebra
using Statistics
using Graphs
using CSV, DataFrames, MetricSpaces, MultivariateStats
using CairoMakie
using TDAmapper
using TDAmapper.ImageCovers, TDAmapper.IntervalCovers
using TDAmapper.Refiners, TDAmapper.Nerves
using Zygote, Optimisers

include(joinpath(@__DIR__, "mapper_draw.jl"))

const DIFF_FIGDIR = normpath(joinpath(@__DIR__, "..", "figures"))
mkpath(DIFF_FIGDIR)

save_diff(name, fig) = begin
    save(joinpath(DIFF_FIGDIR, name), fig; px_per_unit = 2)
    println("wrote $name")
end

# Weight finite H0 bars more strongly than the per-component extended H0 span.
# The span supplies a gradient before branch bars appear; once they do, the
# ordinary-persistence term makes the optimizer prefer persistent branching.
branch_score(g, v; ordinary_weight = 2) =
    total_extended_persistence(g, v; dims = (0,)) +
    ordinary_weight * total_persistence(g, v)
branch_loss(g, v) = -branch_score(g, v)

# Direction-only linear filter for the controlled geometric benchmark.  Without
# this normalization, persistence could increase merely by increasing ||theta||.
function directional_filter(X, theta)
    scale = sqrt(sum(abs2, theta)) + 1e-12
    return LinearFilter()(X, theta / scale)
end

# Output-standardized linear filter for football.  This makes the learned score
# and the fixed-filter scores comparable and prevents variance alone from being
# the optimization target.
function standardized_filter(X, theta)
    values = LinearFilter()(X, theta)
    centered = values .- mean(values)
    return centered ./ (sqrt(mean(abs2, centered)) + 1e-12)
end

"""
    optimize_best(X, theta0; ...)

The package optimizer returns the final iterate.  Mapper's graph combinatorics
make the objective piecewise smooth, so the best label-free objective checkpoint
is more reproducible for an example.  This is the same update as
`optimize_filter`, with the lowest-loss iterate retained.
"""
function optimize_best(X, theta0;
    filter,
    loss = branch_loss,
    cover,
    refiner,
    nerve = SimpleNerve(),
    optimizer = Optimisers.Adam(),
    n_epochs = 200,
)
    theta = collect(float.(theta0))
    state = Optimisers.setup(optimizer, theta)
    history = Float64[]
    best_loss = Inf
    best_theta = copy(theta)
    best_epoch = 0

    for epoch in 1:n_epochs
        filter_values = collect(float.(filter(X, theta)))
        mapper_result = mapper(X, R1Cover(filter_values, cover), refiner, nerve)
        members = mapper_result.C
        graph = mapper_result.g
        objective = candidate -> loss(
            graph, node_filtration(members, filter(X, candidate)))
        result = Zygote.withgradient(objective, theta)
        push!(history, result.val)

        if result.val < best_loss
            best_loss = result.val
            best_theta = copy(theta)
            best_epoch = epoch
        end

        gradient = result.grad[1]
        gradient === nothing && break
        state, theta = Optimisers.update!(state, theta, gradient)
    end

    return (theta = best_theta, final_theta = theta, history = history,
        best_loss = best_loss, best_epoch = best_epoch)
end

function graph_metrics(soft_mapper_result; ordinary_weight = 2)
    graph = soft_mapper_result.g
    components = length(connected_components(graph))
    return (
        score = branch_score(graph, soft_mapper_result.v;
            ordinary_weight = ordinary_weight),
        ordinary_persistence = total_persistence(graph, soft_mapper_result.v),
        nodes = nv(graph),
        edges = ne(graph),
        components = components,
        cycle_rank = ne(graph) - nv(graph) + components,
        tips = count(==(1), degree(graph)),
        branches = count(>=(3), degree(graph)),
    )
end

# -- 1. A rotated table embedded isometrically in R^10 -----------------------

function table_cloud()
    points = Vector{Vector{Float64}}()
    parts = String[]

    # A broad, densely sampled top makes PC1 horizontal.  Four vertical legs
    # carry less variance but are exactly the branching structure Mapper should
    # preserve.
    for x in -2.4:0.2:2.4, y in -1.4:0.2:1.4
        push!(points, [x, y, 1.5])
        push!(parts, "top")
    end
    for (leg, (x, y)) in enumerate(Iterators.product((-2.0, 2.0), (-1.0, 1.0)))
        for z in 0.0:0.05:1.5
            push!(points, [x, y, z])
            push!(parts, "leg$leg")
        end
    end
    return reduce(hcat, points), parts
end

function random_embedding(seed, input_dimension = 3, output_dimension = 10)
    Random.seed!(seed)
    return Matrix(qr(randn(output_dimension, input_dimension)).Q)[:, 1:input_dimension]
end

function table_fit(seed; n_epochs = 250)
    points3, parts = table_cloud()
    embedding = random_embedding(seed)
    points10 = embedding * points3
    space = EuclideanSpace(points10)
    pca = fit(PCA, points10; maxoutdim = 3)
    directions = projection(pca)
    truth = embedding[:, 3]
    cover = Uniform(length = 12, expansion = 0.5)
    refiner = DBscan(radius = 0.28)
    table_loss(g, v) = -branch_score(g, v; ordinary_weight = 6)

    # Four sign configurations are distinct up to global reversal.  Selecting
    # the best topological objective is label-free and avoids a lucky PCA sign.
    fits = map(Iterators.product((-1.0, 1.0), (-1.0, 1.0))) do (s2, s3)
        theta0 = directions * [1.0, s2, s3]
        optimize_best(space, theta0;
            filter = directional_filter,
            loss = table_loss,
            cover = cover,
            refiner = refiner,
            optimizer = Optimisers.Adam(0.015),
            n_epochs = n_epochs)
    end
    # The controlled shape converges cleanly, so use the strongest final
    # iterate.  Football below retains the best checkpoint because its graph is
    # much noisier and the objective is visibly non-monotone.
    final_scores = map(fits) do candidate
        result = soft_mapper(space, candidate.final_theta;
            filter = directional_filter, cover = cover, refiner = refiner)
        branch_score(result.g, result.v; ordinary_weight = 6)
    end
    learned = fits[argmax(final_scores)]

    pca_mapper = soft_mapper(space, directions[:, 1];
        filter = directional_filter, cover = cover, refiner = refiner)
    learned_mapper = soft_mapper(space, learned.final_theta;
        filter = directional_filter, cover = cover, refiner = refiner)
    learned_direction = learned.final_theta / LinearAlgebra.norm(learned.final_theta)

    return (
        points3 = points3,
        parts = parts,
        embedding = embedding,
        truth = truth,
        pca_direction = directions[:, 1],
        learned_direction = learned_direction,
        alignment = abs(dot(learned_direction, truth)),
        pca_mapper = pca_mapper,
        learned_mapper = learned_mapper,
        pca_metrics = graph_metrics(pca_mapper; ordinary_weight = 6),
        learned_metrics = graph_metrics(learned_mapper; ordinary_weight = 6),
        optimization = learned,
    )
end

function table_cloud_figure(result)
    points = result.points3
    pca3 = transpose(result.embedding) * result.pca_direction
    learned3 = transpose(result.embedding) * result.learned_direction
    pca3 ./= LinearAlgebra.norm(pca3)
    learned3 ./= LinearAlgebra.norm(learned3)
    origin = [0.0, 0.0, 0.75]

    fig = Figure(size = (540, 430), backgroundcolor = :white)
    axis = Axis3(fig[1, 1]; aspect = :data, azimuth = -0.34pi,
        elevation = 0.18, perspectiveness = 0.45)
    cloud = [Point3f(point...) for point in eachcol(points)]
    scatter!(axis, cloud; color = points[3, :], colormap = :viridis,
        markersize = 4.0)

    for (direction, color) in ((pca3, "#1f4e79"), (learned3, "#ff6e00"))
        segment = [Point3f((origin .- 1.4direction)...),
            Point3f((origin .+ 1.4direction)...)]
        lines!(axis, segment; color = color, linewidth = 5)
    end
    hidedecorations!(axis)
    hidespines!(axis)

    elements = [LineElement(color = "#1f4e79", linewidth = 5),
        LineElement(color = "#ff6e00", linewidth = 5)]
    Legend(fig[1, 2], elements, ["PC1", "learned"]; framevisible = false)
    colgap!(fig.layout, 2)
    return fig
end

function table_mapper_figure(mapper_result, title)
    return graph_plot(mapper_result;
        positions = layout_packed(mapper_result; seed = 20260802, aspect = 1.0),
        sizes = node_sizes(mapper_result; area_max = 26),
        node_values = mapper_result.v,
        show_legend = false,
        edge_width = 1.2,
        figsize = (470, 400),
        title = title)
end

table_result = table_fit(20260802; n_epochs = 350)
save_diff("diff_table_cloud.png", table_cloud_figure(table_result))
save_diff("diff_table_pca.png",
    table_mapper_figure(table_result.pca_mapper, "PC1 filter"))
save_diff("diff_table_learned.png",
    table_mapper_figure(table_result.learned_mapper, "Learned filter"))

# Independent rotations test that the result is not tied to the hero view.
rotation_results = [table_fit(seed; n_epochs = 250) for seed in 1:8]
rotation_alignments = getproperty.(rotation_results, :alignment)
rotation_successes = count(>(0.95), rotation_alignments)

@assert table_result.alignment > 0.999
@assert table_result.pca_metrics.tips == 2
@assert table_result.learned_metrics.tips == 4
@assert rotation_successes == length(rotation_alignments)

# -- 2. Learn a linear lens on the existing football data --------------------

include(joinpath(@__DIR__, "..", "..", "TDA_workshop_EBT2026",
    "scripts", "build_soccer_data.jl"))

build_info = build_soccer_data()
players = CSV.read(build_info.output_path, DataFrame)
feature_cols = sort(filter(names(players)) do name
    startswith(String(name), "z_") &&
        !(name in ("z_goal_scoring_proxy", "z_playmaking_proxy", "z_defensive_proxy"))
end)

football_matrix = permutedims(Matrix(players[:, feature_cols]))
football_space = EuclideanSpace(football_matrix)
football_pca = fit(PCA, football_matrix; maxoutdim = 3)
football_directions = projection(football_pca)
football_cover = Uniform(length = 20, expansion = 0.6)
football_refiner = DBscan(radius = 2.0, min_cluster_size = 3)

football_fit = optimize_best(football_space, football_directions[:, 1];
    filter = standardized_filter,
    cover = football_cover,
    refiner = football_refiner,
    optimizer = Optimisers.Adam(0.0005),
    n_epochs = 300)

football_pca_mapper = soft_mapper(football_space, football_directions[:, 1];
    filter = standardized_filter,
    cover = football_cover,
    refiner = football_refiner)
football_learned_mapper = soft_mapper(football_space, football_fit.theta;
    filter = standardized_filter,
    cover = football_cover,
    refiner = football_refiner)

position_labels = string.(players.position_group)
function purity_metrics(mapper_result, labels)
    per_node = map(mapper_result.C) do ids
        subset = labels[ids]
        maximum(count(==(label), subset) for label in unique(subset)) / length(subset)
    end
    weights = length.(mapper_result.C)
    return (mean = mean(per_node), weighted = sum(weights .* per_node) / sum(weights))
end

function position_eta_squared(values, labels)
    grand_mean = mean(values)
    between = sum(unique(labels)) do label
        group = values[labels .== label]
        length(group) * (mean(group) - grand_mean)^2
    end
    total = sum((values .- grand_mean) .^ 2)
    return between / total
end

football_pca_metrics = merge(graph_metrics(football_pca_mapper),
    (purity = purity_metrics(football_pca_mapper, position_labels),
        position_eta2 = position_eta_squared(
            football_pca_mapper.f_X, position_labels)))
football_learned_metrics = merge(graph_metrics(football_learned_mapper),
    (purity = purity_metrics(football_learned_mapper, position_labels),
        position_eta2 = position_eta_squared(
            football_learned_mapper.f_X, position_labels)))

@assert football_learned_metrics.score / football_pca_metrics.score > 1.5
@assert football_learned_metrics.ordinary_persistence >
    football_pca_metrics.ordinary_persistence
@assert football_learned_metrics.purity.mean > football_pca_metrics.purity.mean

football_positions = layout_packed(football_learned_mapper)
football_position_index = first(dominant_position(football_learned_mapper, position_labels))
save_diff("filter_learned.png", graph_plot(football_learned_mapper;
    positions = football_positions,
    sizes = node_sizes(football_learned_mapper),
    categories = football_position_index,
    show_legend = false,
    edge_width = 0.8,
    figsize = (470, 400)))

football_direction = football_fit.theta / LinearAlgebra.norm(football_fit.theta)
top_weight_ids = sortperm(abs.(football_direction); rev = true)[1:8]
top_weights = [(feature = String(feature_cols[i]), weight = football_direction[i])
    for i in top_weight_ids]

open(joinpath(DIFF_FIGDIR, "differentiable_stats.txt"), "w") do io
    println(io, "ROTATED TABLE — isometric R3 -> R10 embedding")
    println(io, "hero seed = 20260802")
    println(io, "learned |cos(theta, hidden normal)| = ", table_result.alignment)
    println(io, "PCA metrics = ", table_result.pca_metrics)
    println(io, "learned metrics = ", table_result.learned_metrics)
    println(io, "best checkpoint epoch = ", table_result.optimization.best_epoch,
        " / ", length(table_result.optimization.history))
    println(io, "rotation benchmark alignments = ", rotation_alignments)
    println(io, "rotation successes (alignment > 0.95) = ", rotation_successes,
        " / ", length(rotation_alignments))

    println(io, "\nFOOTBALL — labels withheld during optimization")
    println(io, "features = ", length(feature_cols))
    println(io, "PCA metrics = ", football_pca_metrics)
    println(io, "learned metrics = ", football_learned_metrics)
    println(io, "best checkpoint epoch = ", football_fit.best_epoch,
        " / ", length(football_fit.history))
    println(io, "score improvement = ",
        football_learned_metrics.score / football_pca_metrics.score - 1)
    println(io, "top learned weights:")
    for item in top_weights
        println(io, "  ", item.feature, " = ", item.weight)
    end
end
println("wrote differentiable_stats.txt")
