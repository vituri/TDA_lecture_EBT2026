# Generates every data-derived figure used in mapper-reeb-EBT2026.typ.
#
# Run from this directory:
#
#     julia --project=. scripts/make_figures.jl
#
# Figures land in figures/ and every number quoted on a slide is written to
# figures/stats.txt, so the deck and the code cannot drift apart.
#
# Parameter choices are not guesses: see scripts/explore_soccer.jl and
# scripts/explore2.jl (diagnostics only) for the searches behind them.

using Random
using CairoMakie
using CSV, DataFrames, MetricSpaces, MultivariateStats, Statistics, Graphs
using TDAmapper
using TDAmapper.ImageCovers, TDAmapper.IntervalCovers, TDAmapper.Refiners, TDAmapper.Nerves
using TDAplots
using TDAplots.NaiveLayouts: SFDP

CairoMakie.activate!()
include(joinpath(@__DIR__, "mapper_draw.jl"))

const FIGDIR = joinpath(@__DIR__, "..", "figures")
mkpath(FIGDIR)

save_fig(name, fig) = (save(joinpath(FIGDIR, name), fig; px_per_unit = 2); println("wrote $name"))

# Compress node *area*, not diameter (see mapper_draw.jl).
sized(M) = node_sizes(M; area_max = 34)

# SFDP starts from random positions, so seed before every layout call to keep the
# figures reproducible across runs.
function layout_sfdp(M; seed = 20260724)
    Random.seed!(seed)
    return SFDP()(M.g)
end

# ── 1. The torus: Mapper recovers the Reeb loop ───────────────────────────────
using MetricSpaces.Datasets: torus

Random.seed!(20260724)
X_torus = torus(4000) |> EuclideanSpace
# Projection onto x is a generic Morse-like direction for this embedding: its
# Reeb graph has one loop between two short tails.
f_torus = [x[1] for x in X_torus]
C_torus = R1Cover(f_torus, Uniform(length = 8, expansion = 0.3))
M_torus = classical_mapper(X_torus, C_torus, DBscan(radius = 0.8, min_cluster_size = 5))

torus_node_values = node_colors(M_torus, f_torus)
torus_figure = mapper_plot(M_torus;
    node_positions = layout_torus_reeb(M_torus, torus_node_values),
    node_size = node_sizes(M_torus; area_max = 28),
    node_values = torus_node_values,
    edge_size = 1.5)
torus_axis = only(filter(x -> x isa Axis, torus_figure.content))
limits!(torus_axis, -1.05, 1.05, -1.12, 1.12)
save_fig("torus_mapper.png", torus_figure)

let g = M_torus.g, d = degree(g)
    println("torus: nodes=$(nv(g)) edges=$(ne(g)) components=$(length(connected_components(g))) " *
            "loops=$(ne(g) - nv(g) + length(connected_components(g))) " *
            "all-degree-2=$(all(==(2), d))")
end

# ── 2. Soccer players ─────────────────────────────────────────────────────────
include(joinpath(@__DIR__, "..", "..", "TDA_workshop_EBT2026", "scripts", "build_soccer_data.jl"))

build_info = build_soccer_data()
players = CSV.read(build_info.output_path, DataFrame)

feature_cols = sort(filter(names(players)) do name
    startswith(String(name), "z_") &&
        !(name in ("z_goal_scoring_proxy", "z_playmaking_proxy", "z_defensive_proxy"))
end)

X = permutedims(Matrix(players[:, feature_cols]))
space = EuclideanSpace(X)

pc_model = fit(PCA, X; maxoutdim = 2)
pc_scores = predict(pc_model, X)
pc1, pc2 = vec(pc_scores[1, :]), vec(pc_scores[2, :])

player_names = string.(players.player)
pos_labels = string.(players.position_group)

# Two geometric filters and one chosen by hand, for the filter comparison.
ecc = MetricSpaces.eccentricity(space)         # mean distance to every player
dens = MetricSpaces.knn_density(space; k = 15)
attack = players.z_xg_per90 .+ players.z_xa_per90

# The deck's main graph. DBSCAN per slice (rather than the histogram-gap refiner)
# is what lets a slice split into several clusters, which is what produces
# branching instead of a bare path.
#
# DO NOT retune without re-reading stats.txt: the slides quote this graph's node
# and edge counts, its purity, and four named tips.
COVER = Uniform(length = 14, expansion = 0.4)
REFINER = DBscan(radius = 2.5, min_cluster_size = 8)

M = classical_mapper(space, R1Cover(pc1, COVER), REFINER)
pos = layout_packed(M)
sz = sized(M)
pos_idx, pos_ties = dominant_position(M, pos_labels)

# Names for the main graph: the tips the slide talks about, plus the household
# names an audience will look for.
MAIN_NAMES = ["Luis Muriel", "Robert Lewandowski", "Karim Benzema", "Kylian Mbappé",
    "Neymar", "Lionel Messi", "Kevin De Bruyne", "Cristiano Ronaldo",
    "Casemiro", "Thiago Silva", "Trent Alexander-Arnold"]

# Used only as the middle panel of the resolution triptych, whose other two
# panels have no legend: so this one must not either, or the row goes lopsided.
# The legend is established on the labelled version of this same graph.
save_fig("soccer_position.png", graph_plot(M;
    positions = pos, sizes = sz, categories = pos_idx,
    show_legend = false, figsize = (520, 430)))

save_fig("soccer_named.png", graph_plot(M;
    positions = pos, sizes = sz, categories = pos_idx,
    labels = label_nodes(M, player_names, MAIN_NAMES),
    figsize = (960, 600)))

# A second, audience-facing reading of the same graph. Each tab labels a
# contiguous part of the PC1 progression, so the names stay legible while all
# 22 nodes receive an example across the three views. The helper verifies that
# every displayed player really belongs to the numbered node. This explicit
# node assignment matters because overlap can put the same pair in two adjacent
# nodes even when a third player distinguishes the intended neighbourhood.
function verified_player_labels(M, names, groups)
    labels = Dict{Int,String}()
    for (node, group) in groups
        ids = map(group) do player
            id = findfirst(==(player), names)
            isnothing(id) && error("player not in dataset: $player")
            id
        end
        all(id -> id in M.C[node], ids) ||
            error("players do not all belong to node $node: $(join(group, ", "))")
        short = short_name.(group)
        body = length(short) > 2 ? join(short[1:2], " + ") * "\n" * join(short[3:end], " + ") :
            join(short, " + ")
        labels[node] = "N$node · " * body
    end
    return labels
end

ATTACK_EXAMPLES = Dict(
    1 => ["Luis Muriel"],
    2 => ["Robert Lewandowski", "Lionel Messi"],
    3 => ["Kylian Mbappé", "Neymar", "Kevin De Bruyne"],
    4 => ["Erling Haaland", "Harry Kane"],
    5 => ["Cristiano Ronaldo", "Jadon Sancho"],
    6 => ["Karim Benzema", "Mohamed Salah"],
    7 => ["Son Heung-min", "Antoine Griezmann"],
    8 => ["Jack Grealish", "Paulo Dybala"],
)

MIDFIELD_EXAMPLES = Dict(
    9 => ["Mason Mount", "Yannick Carrasco"],
    10 => ["İlkay Gündoğan", "Joshua Kimmich"],
    11 => ["Toni Kroos", "Trent Alexander-Arnold"],
    12 => ["Kai Havertz", "Achraf Hakimi"],
    13 => ["João Cancelo", "Christian Eriksen"],
    14 => ["Luka Modrić", "Paul Pogba"],
    15 => ["Casemiro", "Frenkie de Jong"],
    16 => ["Marco Verratti", "Bruno Guimarães"],
    17 => ["Jorginho", "Idrissa Gana Gueye"],
)

DEFENSE_EXAMPLES = Dict(
    18 => ["N'Golo Kanté", "Sergio Busquets", "Sergio Ramos"],
    19 => ["Marquinhos", "Raphaël Varane", "Leonardo Bonucci"],
    20 => ["Daniele Rugani", "Idrissa Gana Gueye"],
    21 => ["Thiago Silva", "Rúben Dias", "Kalidou Koulibaly"],
    22 => ["Kenny Tete"],
)

player_views = Dict(
    "attack" => verified_player_labels(M, player_names, ATTACK_EXAMPLES),
    "midfield" => verified_player_labels(M, player_names, MIDFIELD_EXAMPLES),
    "defense" => verified_player_labels(M, player_names, DEFENSE_EXAMPLES),
)
@assert sort(vcat([collect(keys(player_views[tag])) for tag in ("attack", "midfield", "defense")]...)) ==
    collect(eachindex(M.C))

# The default label direction points away from a node's neighbours. Alternating
# a few directions on the dense attacking and midfield chains prevents adjacent
# callouts from colliding without changing the graph layout itself.
player_label_directions = Dict(
    "attack" => Dict(
        1 => Point2f(-1, 1), 2 => Point2f(1, 1),
        3 => Point2f(-1, -1), 4 => Point2f(-1, -0.2),
        5 => Point2f(-1, 1), 6 => Point2f(1, -1),
        7 => Point2f(1, -0.2), 8 => Point2f(-1, 0.5),
    ),
    "midfield" => Dict(
        9 => Point2f(1, -1), 10 => Point2f(-1, 0.7),
        11 => Point2f(1, -0.7), 12 => Point2f(-1, -0.4),
        13 => Point2f(1, -0.2), 14 => Point2f(-1, 1),
        15 => Point2f(1, 0.8), 16 => Point2f(-1, 0.4),
        17 => Point2f(1, 0.8),
    ),
    "defense" => Dict{Int,Point2f}(),
)

for tag in ("attack", "midfield", "defense")
    save_fig("soccer_players_$tag.png", graph_plot(M;
        positions = pos, sizes = sz, categories = pos_idx,
        labels = player_views[tag], label_directions = player_label_directions[tag],
        label_fontsize = 20, show_legend = false,
        figsize = (1100, 620)))
end

# The same nodes and the same layout, recoloured by each role.
for (name, col, cmap) in (
    ("soccer_goals.png", players.goal_scoring_proxy, :inferno),
    ("soccer_playmaking.png", players.playmaking_proxy, :viridis),
    ("soccer_defense.png", players.defensive_proxy, :viridis),
)
    save_fig(name, graph_plot(M; positions = pos, sizes = sz,
        node_values = node_colors(M, col), colormap = cmap, figsize = (560, 460)))
end

# Brazilians.
brazilian_share = node_colors(M, Float64.(players.is_brazilian); f = mean)
save_fig("soccer_brazil.png", graph_plot(M; positions = pos, sizes = sz,
    node_values = brazilian_share, colormap = :YlGnBu,
    labels = label_nodes(M, player_names,
        ["Neymar", "Rodrygo", "Gabriel Jesus", "Casemiro", "Thiago Silva", "Marcelo"])))

# PCA baseline for the "why not a scatter?" contrast.
save_fig("soccer_pca.png", metricspace_plot(EuclideanSpace(pc_scores),
    color = pos_labels, markersize = 7))

# ── 3. Resolution / parameter sensitivity ─────────────────────────────────────
# Coarse end: the histogram-gap refiner collapses each slice to one cluster, so
# the graph is a path: the role spectrum with no branches.
M_coarse = classical_mapper(space, R1Cover(pc1, Uniform(length = 12, expansion = 0.25)),
    FirstEmptyBin(num_bins = 10))
save_fig("soccer_coarse.png", graph_plot(M_coarse;
    positions = layout_packed(M_coarse), sizes = sized(M_coarse),
    categories = first(dominant_position(M_coarse, pos_labels)),
    show_legend = false, figsize = (520, 430)))

# Fine end: same filter, smaller DBSCAN radius: more, smaller branches.
M_fine = classical_mapper(space, R1Cover(pc1, Uniform(length = 18, expansion = 0.5)),
    DBscan(radius = 2.0, min_cluster_size = 3))
save_fig("soccer_fine.png", graph_plot(M_fine;
    positions = layout_packed(M_fine), sizes = sized(M_fine),
    categories = first(dominant_position(M_fine, pos_labels)),
    show_legend = false, figsize = (520, 430)))

# ── 4. Change the filter, change the question ─────────────────────────────────
# Same cover and same refiner throughout, so the only difference is the filter.
ZOO_COVER = Uniform(length = 20, expansion = 0.6)
ZOO_REFINER = DBscan(radius = 2.0, min_cluster_size = 3)
zoo = Dict{String,Any}() # filter comparison

for (tag, f) in (("pc1", pc1), ("ecc", ecc), ("dens", dens), ("attack", attack))
    Mz = classical_mapper(space, R1Cover(f, ZOO_COVER), ZOO_REFINER)
    zoo[tag] = Mz
    save_fig("filter_$tag.png", graph_plot(Mz;
        positions = layout_packed(Mz), sizes = node_sizes(Mz),
        categories = first(dominant_position(Mz, pos_labels)),
        show_legend = false, edge_width = 0.8, figsize = (470, 400)))
end

# ── 5. Eccentricity: a centrality lens makes flares ──────────────────────────
# The clustering refiner operates independently inside every pullback-cover
# element. These choices span an adaptive linkage heuristic, a density rule,
# and a fixed-k partition. Trivial() remains a useful conceptual baseline, but
# its optimized refine_cover method preserves empty raw-cover elements, so it is
# deliberately not used for this data-derived comparison.
CLUSTER_C = R1Cover(pc1, ZOO_COVER)
clusterers = Dict{String,Any}()
for (tag, R) in (
    ("firstempty", FirstEmptyBin(num_bins = 10)),
    ("dbscan", ZOO_REFINER),
    ("kmeans", KMeans(k = 2)),
)
    Random.seed!(20260724) # KMeans is random; the other refiners ignore this.
    Mc = classical_mapper(space, CLUSTER_C, R)
    clusterers[tag] = Mc
    save_fig("cluster_$tag.png", graph_plot(Mc;
        positions = layout_packed(Mc), sizes = node_sizes(Mc),
        categories = first(dominant_position(Mc, pos_labels)),
        show_legend = false, edge_width = 0.8, figsize = (470, 400)))
end

# Level sets of "mean distance to everyone else" are shells around the dense
# core, so extremes in *different* directions land in the same slice and DBSCAN
# splits them apart. The starfish is partly made by this choice of filter: which
# is the point of putting it next to the PC1 graph.
M_ecc = classical_mapper(space, R1Cover(ecc, Uniform(length = 20, expansion = 0.5)),
    DBscan(radius = 2.0, min_cluster_size = 3))
pos_ecc = layout_packed(M_ecc)
# Muriel is named on the PC1 graph and lands in the same crowded satellite row as
# De Bruyne here, so he is left off this one.
ECC_NAMES = ["Robert Lewandowski", "Lionel Messi", "Kylian Mbappé",
    "Neymar", "Kevin De Bruyne", "Erling Haaland", "Karim Benzema",
    "Thiago Silva", "Trent Alexander-Arnold", "N'Golo Kanté", "Marcelo"]

save_fig("soccer_ecc.png", graph_plot(M_ecc;
    positions = pos_ecc, sizes = node_sizes(M_ecc),
    categories = first(dominant_position(M_ecc, pos_labels)),
    labels = label_nodes(M_ecc, player_names, ECC_NAMES),
    edge_width = 0.8, figsize = (960, 600)))

# ── 6. Two lenses: the grid cover, and the web it produces ───────────────────
# With one filter every node lies in one interval and adjacent intervals are the
# only ones that meet, so the graph maps onto a path. A 2-D grid cover has cells
# overlapping in two directions, so the nerve picks up 4-cycles everywhere.
LENS2 = collect(zip(pc1, pc2))
M_2lens = classical_mapper(space,
    R2Cover(LENS2, Uniform(length = 12, expansion = 0.4), Uniform(length = 12, expansion = 0.4)),
    DBscan(radius = 2.5, min_cluster_size = 3))
pos_2 = layout_packed(M_2lens)
LENS_NAMES = ["Robert Lewandowski", "Lionel Messi", "Kylian Mbappé", "Neymar",
    "Kevin De Bruyne", "Erling Haaland", "Thiago Silva", "N'Golo Kanté",
    "Trent Alexander-Arnold", "Casemiro"]

save_fig("soccer_2lens.png", graph_plot(M_2lens;
    positions = pos_2, sizes = node_sizes(M_2lens),
    categories = first(dominant_position(M_2lens, pos_labels)),
    labels = label_nodes(M_2lens, player_names, LENS_NAMES),
    edge_width = 0.5, edge_alpha = 0.35, figsize = (960, 610)))

# The same graph without labels, for a side-by-side against the 1-lens graph.
save_fig("soccer_2lens_plain.png", graph_plot(M_2lens;
    positions = pos_2, sizes = node_sizes(M_2lens),
    categories = first(dominant_position(M_2lens, pos_labels)),
    edge_width = 0.5, edge_alpha = 0.35, show_legend = false, figsize = (520, 430)))

# ── 7. The overlap knob has a threshold at expansion = 1 ─────────────────────
# Uniform puts interval centres one step apart with radius (step/2)(1 + e), so
# slices i and i+2 (2 steps apart) intersect exactly when e > 1. Below that every
# edge joins consecutive slices and the graph is layered; above it, shortcuts
# appear and the layering is gone.
overlap = Dict{Float64,Any}()
for e in (0.4, 1.0, 1.4)
    Me = classical_mapper(space, R1Cover(pc1, Uniform(length = 14, expansion = e)),
        DBscan(radius = 2.5, min_cluster_size = 3))
    overlap[e] = Me
    save_fig("overlap_$(replace(string(e), "." => "")).png", graph_plot(Me;
        positions = layout_packed(Me), sizes = node_sizes(Me),
        categories = first(dominant_position(Me, pos_labels)),
        show_legend = false, edge_width = 0.8, figsize = (470, 400)))
end

# ── 8. The nerve is a separate choice ────────────────────────────────────────
# Same cover, same clusters, same nodes: only the rule for drawing an edge
# changes, so this isolates the nerve from everything else. Deliberately run on
# the *same* two-lens graph as the hero figure above, so the slide prunes a web
# the audience has already seen rather than introducing a new one.
NERVE_C = R2Cover(LENS2,
    Uniform(length = 12, expansion = 0.4), Uniform(length = 12, expansion = 0.4))
NERVE_R = DBscan(radius = 2.5, min_cluster_size = 3)
nerves = Dict{String,Any}()
for (tag, N) in (
    ("simple", SimpleNerve()),
    ("min2", MinCountNerve(2)),
    ("percentage", PercentageNerve(0.2, :or)),
    ("jaccard", JaccardNerve(0.1)),
)
    Mn = classical_mapper(space, NERVE_C, NERVE_R, N)
    nerves[tag] = Mn
end

# All variants have exactly the same nodes. Keeping the simple-nerve layout
# fixed makes the interactive comparison visibly prune edges in place.
pos_nerve = layout_packed(nerves["simple"])
for tag in ("simple", "min2", "percentage", "jaccard")
    Mn = nerves[tag]
    save_fig("nerve_$tag.png", graph_plot(Mn;
        positions = pos_nerve, sizes = node_sizes(Mn),
        categories = first(dominant_position(Mn, pos_labels)),
        show_legend = false, edge_width = 0.6, edge_alpha = 0.4, figsize = (470, 400)))
end

# ── 9. Ball Mapper: no filter, one radius ────────────────────────────────────
# 18-dimensional z-scored data has concentrated pairwise distances, so the single
# radius has to separate scales that are barely separated. Two radii either side
# of the useful range show both failure modes.
Random.seed!(20260724)
L_ball = farthest_points_sample_ids(space, 100)
balls = Dict{Float64,Any}()
for eps in (3.0, 3.6)
    Mb = ball_mapper(space, L_ball, eps)
    balls[eps] = Mb
    save_fig("ball_$(replace(string(eps), "." => "")).png", graph_plot(Mb;
        positions = layout_packed(Mb), sizes = node_sizes(Mb),
        categories = first(dominant_position(Mb, pos_labels)),
        show_legend = false, edge_width = 0.5, edge_alpha = 0.35, figsize = (470, 400)))
end

# ── 10. The numbers quoted on the slides ─────────────────────────────────────
node_purity(M, labels) = map(M.C) do ids
    sub = labels[ids]
    maximum(count(==(l), sub) for l in unique(sub)) / length(sub)
end

node_exemplars(M, players) = map(M.C) do ids
    sub = players[ids, :]
    sub.player[argmax(sub.overall)]
end

# Highest-rated Brazilian in each node, when there is one.
node_brazilians(M, players) = map(M.C) do ids
    sub = players[ids, :]
    br = sub[sub.is_brazilian, :]
    nrow(br) == 0 ? "" : br.player[argmax(br.overall)]
end

function summarise(io, label, M)
    g = M.g
    d = degree(g)
    purity = mean(node_purity(M, pos_labels))
    baseline = maximum(count(==(l), pos_labels) for l in unique(pos_labels)) / length(pos_labels)
    _, ties = dominant_position(M, pos_labels)
    println(io, "\n══ $label ══")
    println(io, "  nodes=$(nv(g)) edges=$(ne(g)) components=$(length(connected_components(g))) " *
                "cycle_rank=$(ne(g) - nv(g) + length(connected_components(g)))")
    println(io, "  tips(deg 1)=$(count(==(1), d)) branch(deg>=3)=$(count(>=(3), d)) isolated=$(count(==(0), d))")
    println(io, "  node sizes: min=$(minimum(length.(M.C))) median=$(median(length.(M.C))) max=$(maximum(length.(M.C)))")
    println(io, "  mean node purity=$(round(purity, digits=3))  vs largest-group baseline=$(round(baseline, digits=3))")
    println(io, "  nodes with a tied dominant position=$ties")
end

function name_table(io, label, M; sortcol = :goals_z)
    st = DataFrame(node_statistics(M,
        players[:, [:goal_scoring_proxy, :playmaking_proxy, :defensive_proxy, :overall]]))
    tbl = DataFrame(
        node = st.node, size = length.(M.C), degree = degree(M.g),
        position = POSITIONS[first(dominant_position(M, pos_labels))],
        goals_z = round.(st.goal_scoring_proxy_z, digits = 2),
        play_z = round.(st.playmaking_proxy_z, digits = 2),
        def_z = round.(st.defensive_proxy_z, digits = 2),
        brazil = round.(node_colors(M, Float64.(players.is_brazilian); f = mean), digits = 2),
        exemplar = node_exemplars(M, players),
        top_brazilian = node_brazilians(M, players),
    )
    println(io, "\n  ── $label: tips (degree <= 1) ──")
    show(io, sort(tbl[tbl.degree .<= 1, :], sortcol, rev = true); allrows = true, allcols = true)
    println(io, "\n\n  ── $label: all nodes by $sortcol ──")
    show(io, sort(tbl, sortcol, rev = true); allrows = true, allcols = true)
    println(io)
end

open(joinpath(FIGDIR, "stats.txt"), "w") do io
    println(io, "source     = ", build_info.source)
    println(io, "season     = ", join(unique(players.season_label), ", "))
    println(io, "players    = ", nrow(players))
    println(io, "features   = ", length(feature_cols), "  ", feature_cols)
    println(io, "brazilians = ", sum(players.is_brazilian),
        "  (", round(100 * mean(players.is_brazilian), digits = 1), "% base rate)")
    println(io, "PCA        = PC1 ", round(100 * principalvars(pc_model)[1] / var(pc_model), digits = 1),
        "% of variance, PC2 ", round(100 * principalvars(pc_model)[2] / var(pc_model), digits = 1), "%")

    summarise(io, "MAIN  R1Cover(PC1) Uniform(14, 0.4) + DBscan(2.5, min 8)", M)
    name_table(io, "MAIN", M)
    summarise(io, "COARSE  Uniform(12, 0.25) + FirstEmptyBin(10)", M_coarse)
    summarise(io, "FINE  Uniform(18, 0.5) + DBscan(2.0, min 3)", M_fine)

    println(io, "\n\n╔══ FILTER COMPARISON: same cover Uniform(20, 0.6), same DBscan(2.0, min 3) ══╗")
    for tag in ("pc1", "ecc", "dens", "attack")
        summarise(io, "filter = $tag", zoo[tag])
    end

    println(io, "\n\n╔══ CLUSTERING COMPARISON: same PC1 filter + Uniform(20, 0.6) cover ══╗")
    for tag in ("firstempty", "dbscan", "kmeans")
        summarise(io, "refiner = $tag", clusterers[tag])
    end

    println(io, "\n\n╔══ ECCENTRICITY FLARES  Uniform(20, 0.5) + DBscan(2.0, min 3) ══╗")
    summarise(io, "ecc", M_ecc)
    name_table(io, "ECC", M_ecc)

    println(io, "\n\n╔══ TWO LENSES  R2Cover(PC1, PC2) 12x12 exp 0.4 + DBscan(2.5, min 3) ══╗")
    summarise(io, "pc1 x pc2", M_2lens)

    println(io, "\n\n╔══ OVERLAP  R1Cover(PC1) 14 slices, DBscan(2.5, min 3) ══╗")
    println(io, "  radius = (step/2)(1+e); slices i and i+2 are 2 steps apart,")
    println(io, "  so non-adjacent slices first intersect at e > 1.")
    for e in (0.4, 1.0, 1.4)
        summarise(io, "expansion = $e", overlap[e])
    end

    println(io, "\n\n╔══ NERVE  same cover + clusters, different edge rule ══╗")
    for tag in ("simple", "min2", "percentage", "jaccard")
        summarise(io, "nerve = $tag", nerves[tag])
    end

    println(io, "\n\n╔══ BALL MAPPER  100 farthest-point landmarks ══╗")
    println(io, "  pairwise distance quantiles: see figures/explore.txt")
    for eps in (3.0, 3.6)
        summarise(io, "epsilon = $eps", balls[eps])
    end

    println(io, "\n\n╔══ Brazilians in the main graph ══╗")
    br = players[players.is_brazilian, :]
    println(io, "  top 12 Brazilians by overall:")
    show(io, first(sort(br[:, [:player, :team, :position_group, :overall,
        :goal_scoring_proxy, :playmaking_proxy, :defensive_proxy]], :overall, rev = true), 12);
        allrows = true, allcols = true)
    println(io, "\n  most-Brazilian nodes:")
    tbl = DataFrame(
        node = 1:length(M.C), size = length.(M.C), degree = degree(M.g),
        share = round.(brazilian_share, digits = 3),
        n_brazil = map(ids -> sum(players.is_brazilian[ids]), M.C),
        position = POSITIONS[pos_idx],
        top_brazilian = node_brazilians(M, players),
    )
    show(io, first(sort(tbl, :share, rev = true), 10); allrows = true, allcols = true)

    println(io, "\n\n╔══ where the named players landed ══╗")
    for (tag, Mx, wanted) in (("MAIN", M, MAIN_NAMES), ("ECC", M_ecc, ECC_NAMES),
        ("2LENS", M_2lens, LENS_NAMES))
        println(io, "\n  $tag:")
        for (k, txt) in sort(collect(label_nodes(Mx, player_names, wanted)))
            println(io, "    node $k (size $(length(Mx.C[k])), degree $(degree(Mx.g)[k])): $txt")
        end
    end
    println(io)
end
println("wrote stats.txt")
