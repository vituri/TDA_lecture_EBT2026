# Drawing helpers for the football figures.
#
# TDAplots' `mapper_plot` handles the simple cases and is what the code slides
# show. Two things it does not expose are needed here:
#
#   * an *ordered* categorical palette. Its string branch groups labels with
#     `sort`, so Defender / Forward / Midfielder comes out alphabetical — which
#     scrambles the one axis the football graph is about.
#   * per-node text, so famous players can be named on the graph.
#
# Both are rendering concerns only: the Mapper objects are built with the public
# API exactly as on the slides, and nothing here touches topology.

using Random
using Graphs
using CairoMakie
using TDAplots: rescale
using TDAplots.NaiveLayouts: Stress, SFDP

# Ordinal, not alphabetical. Cold → warm follows defence → attack.
const POSITIONS = ["Defender", "Midfielder", "Forward"]
const POS_COLORS = Makie.to_color.(["#1f4e79", "#79b04a", "#c0392b"])

"""
    dominant_position(M, pos) -> (indices, n_ties)

Index into `POSITIONS` of the most common position in each node.

`node_colors`' default mode function joins ties with `/`, which invents
categories — `position_group` has exactly three values, so a legend entry like
"Defender/Midfielder" is an artefact of tie-joining and not a role. Here ties are
broken toward the more defensive role and counted, so the count can be reported
instead of hidden.
"""
function dominant_position(M, pos)
    ties = 0
    idx = map(M.C) do ids
        counts = [count(==(p), pos[ids]) for p in POSITIONS]
        winners = findall(==(maximum(counts)), counts)
        length(winners) > 1 && (ties += 1)
        first(winners)
    end
    return idx, ties
end

"""
    node_sizes(M; area_max = nothing)

Marker sizes proportional to the *square root* of cluster size, so node **area**
tracks population. Without this a 452-player cluster swallows its neighbours.

The cap shrinks as the graph grows: at 22 nodes a 34pt disc reads well, at 150 it
is a blob.
"""
function node_sizes(M; area_max = nothing)
    n = length(M.C)
    mx = something(area_max, clamp(160 / sqrt(n), 8, 34))
    return rescale(sqrt.(length.(M.C)); min = clamp(mx / 4, 3, 8), max = mx)
end

# One component's own layout. Stress majorization spreads a small graph more
# evenly than SFDP, which is what these figures need; two- and one-node pieces
# have no layout problem to solve.
function _component_layout(sub, seed)
    nv(sub) == 1 && return [Point2f(0, 0)]
    nv(sub) == 2 && return [Point2f(0, 0), Point2f(1, 0)]
    Random.seed!(seed)
    return [Point2f(p[1], p[2]) for p in Stress()(sub)]
end

"""
    layout_packed(M; seed = 20260724, pad = 0.9) -> Vector{Point2f}

Lay out each connected component separately, then pack the components into a
tidy block, largest first.

A force-directed layout has nothing to push *disconnected* pieces anywhere in
particular: they drift to wherever the random start left them, so a graph with a
dozen singletons spends most of its canvas on whitespace and drops the odd
isolated node on top of the main component. Packing keeps the big component
readable and puts the one-of-a-kind nodes in a legible margin.

A component's box side grows like `n^exponent`. Equal area per node (`0.5`) turns
out to over-reward the satellites: a 1-node piece needs no room to show internal
structure and a 40-node one needs all it can get, so the default leans steeper.

`aspect` is the width:height the packed block aims for, so it can be matched to
the figure it will be drawn into instead of coming out square.
"""
function layout_packed(M; seed = 20260724, pad = 0.8, exponent = 0.68, aspect = 1.6)
    g = M.g
    comps = sort(connected_components(g), by = length, rev = true)

    laid = map(comps) do comp
        sub, _ = induced_subgraph(g, comp)     # vertex i of sub is comp[i]
        pts = _component_layout(sub, seed)
        xs, ys = first.(pts), last.(pts)
        w, h = maximum(xs) - minimum(xs), maximum(ys) - minimum(ys)
        s = max(w, h) < 1e-6 ? 1.0 : length(comp)^exponent / max(w, h)
        shifted = [Point2f((p[1] - minimum(xs)) * s, (p[2] - minimum(ys)) * s) for p in pts]
        (comp, shifted, w * s + pad, h * s + pad)
    end

    # Shelf packing. The shelf is at least as wide as the largest component so
    # that one is never wrapped, and otherwise wide enough to hit `aspect`.
    total_area = sum(b[3] * b[4] for b in laid)
    target = max(1.05 * laid[1][3], sqrt(aspect * total_area))

    out = Vector{Point2f}(undef, nv(g))
    x = y = row_h = 0.0
    for (comp, pts, bw, bh) in laid
        if x > 0 && x + bw > target
            x = 0.0
            y += row_h
            row_h = 0.0
        end
        for (i, node) in enumerate(comp)
            out[node] = Point2f(x + pad / 2 + pts[i][1], -(y + pad / 2 + pts[i][2]))
        end
        x += bw
        row_h = max(row_h, bh)
    end
    return out
end

# Surnames keep the labels short enough to sit beside a node without colliding.
# Brazilians go by the single name they actually play under.
const SHORT_NAME = Dict(
    "Robert Lewandowski" => "Lewandowski", "Lionel Messi" => "Messi",
    "Cristiano Ronaldo" => "Ronaldo", "Kylian Mbappé" => "Mbappé",
    "Kevin De Bruyne" => "De Bruyne", "Karim Benzema" => "Benzema",
    "Erling Haaland" => "Haaland", "Luis Muriel" => "Muriel",
    "Trent Alexander-Arnold" => "Alexander-Arnold", "N'Golo Kanté" => "Kanté",
    "Neymar" => "Neymar", "Casemiro" => "Casemiro", "Marcelo" => "Marcelo",
    "Thiago Silva" => "Thiago Silva", "Rodrygo" => "Rodrygo",
    "Gabriel Jesus" => "Gabriel Jesus",
)
short_name(n) = get(SHORT_NAME, n, String(last(split(n))))

"""
    label_nodes(M, names, wanted) -> Dict{Int,String}

Choose one node per requested player and return the text to draw there.

A player belongs to *every* cover element containing them, so a name can have
several candidate nodes — that multiplicity is exactly what puts an edge between
those nodes. We label the **smallest** node containing the player: the most
specific cluster they fall in, which is the most informative one to name. Players
landing on the same node share a label, which is itself worth seeing.
"""
function label_nodes(M, names, wanted; max_per_node = 3)
    groups = Dict{Int,Vector{String}}()
    missing_names = String[]
    for w in wanted
        i = findfirst(==(w), names)
        if isnothing(i)
            push!(missing_names, w)
            continue
        end
        cands = [k for k in eachindex(M.C) if i in M.C[k]]
        isempty(cands) && continue
        push!(get!(groups, cands[argmin([length(M.C[k]) for k in cands])], String[]), w)
    end
    isempty(missing_names) || @warn "names not in dataset" missing_names
    return Dict(k => _join_names(v, max_per_node) for (k, v) in groups)
end

function _join_names(v, cap)
    short = short_name.(v)
    length(short) <= cap && return join(short, " + ")
    return join(short[1:cap], " + ") * " +$(length(short) - cap)"
end

# Push each label away from the node's own neighbours, so on a tip it lands just
# past the end of the flare rather than back along it. Isolated nodes have no
# neighbours to push off, so they fall back to the graph's centre.
function _place_labels!(ax, positions, labels, extent, g)
    isempty(labels) && return
    ctr = sum(positions) / length(positions)
    pad = 0.06 * extent
    for (k, txt) in labels
        p = positions[k]
        nb = neighbors(g, k)
        ref = isempty(nb) ? ctr : sum(positions[nb]) / length(nb)
        v = p - ref
        r = hypot(v[1], v[2])
        dir = r < 1e-9 ? Point2f(0, 1) : Point2f(v[1] / r, v[2] / r)
        anchor = p + dir * pad
        # A leader line: in a graph this dense, a name floating near several nodes
        # is a name attached to none of them.
        lines!(ax, [p + dir * pad * 0.28, anchor]; color = (:gray45, 0.9), linewidth = 0.7)
        align = (dir[1] >= 0 ? :left : :right, dir[2] >= 0 ? :bottom : :top)
        # A thin white outline keeps a name legible where it crosses an edge; any
        # thicker and it eats the glyph strokes at this font size.
        text!(ax, anchor; text = txt, fontsize = 12, align = align,
            color = :gray10, font = :bold,
            strokewidth = 0.8, strokecolor = (:white, 0.85))
    end
end

"""
    graph_plot(M; positions, sizes, categories | node_values, ...) -> Figure

Draw a Mapper graph. Pass `categories` (indices into `POSITIONS`) for the ordered
position palette with a legend in ordinal order, or `node_values` for a numeric
colourscale with a colourbar.
"""
function graph_plot(M;
    positions,
    sizes = node_sizes(M),
    categories = nothing,
    node_values = nothing,
    colormap = :viridis,
    labels = Dict{Int,String}(),
    edge_width = 1.0,
    edge_alpha = 0.5,
    figsize = (820, 560),
    show_legend = true,
    title = nothing,
)
    pts = [Point2f(p[1], p[2]) for p in positions]
    xs, ys = first.(pts), last.(pts)
    extent = max(maximum(xs) - minimum(xs), maximum(ys) - minimum(ys))

    fig = Figure(size = figsize, backgroundcolor = :white)
    ax = Axis(fig[1, 1]; backgroundcolor = :white,
        title = something(title, ""), titlesize = 15)

    if ne(M.g) > 0
        seg = Point2f[]
        for e in edges(M.g)
            push!(seg, pts[src(e)], pts[dst(e)])
        end
        linesegments!(ax, seg; color = (:gray25, edge_alpha), linewidth = edge_width)
    end

    if !isnothing(categories)
        scatter!(ax, pts; markersize = sizes, color = POS_COLORS[categories],
            strokewidth = 0.5, strokecolor = :white)
        if show_legend
            elems = [MarkerElement(marker = :circle, color = c, markersize = 12)
                     for c in POS_COLORS]
            Legend(fig[1, 2], elems, POSITIONS; framevisible = false,
                labelsize = 13, patchsize = (14, 14))
        end
    else
        cr = extrema(node_values)
        scatter!(ax, pts; markersize = sizes, color = node_values,
            colormap = colormap, colorrange = cr,
            strokewidth = 0.5, strokecolor = :white)
        show_legend && Colorbar(fig[1, 2]; colormap = colormap, colorrange = cr,
            width = 12, ticklabelsize = 11)
    end

    _place_labels!(ax, pts, labels, extent, M.g)

    hidedecorations!(ax)
    hidespines!(ax)
    # `hidedecorations!` does not stop glyphs clipping at the frame, so make room —
    # horizontally in proportion to the longest label, since labels are anchored
    # at a node and run outward from there.
    widest = isempty(labels) ? 0 : maximum(length, values(labels))
    mx = isempty(labels) ? 0.06 : clamp(0.017 * widest, 0.16, 0.45)
    my = isempty(labels) ? 0.06 : 0.12
    xlims!(ax, minimum(xs) - mx * extent, maximum(xs) + mx * extent)
    ylims!(ax, minimum(ys) - my * extent, maximum(ys) + my * extent)
    colgap!(fig.layout, 6)

    return fig
end
