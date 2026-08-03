# Smoke test for the torus calculation shown visually in the deck.
# If this file stops running, the slide is wrong. Run it in a fresh process:
#     julia --project=. scripts/verify_slide_code.jl

using TDAmapper, TDAplots, MetricSpaces
using TDAmapper.ImageCovers,
      TDAmapper.IntervalCovers,
      TDAmapper.Refiners
using MetricSpaces.Datasets: torus

X = torus(4000)
f = [x[1] for x in X]        # projection onto x

C = R1Cover(f,
      Uniform(length = 8, expansion = 0.3))
M = classical_mapper(X, C,
      DBscan(radius = 0.8, min_cluster_size = 5))

mapper_plot(M,
    node_values = node_colors(M, f))

# ── everything below is the check, not part of the slide ──
using Graphs
println("slide example ran: nodes=$(nv(M.g)) edges=$(ne(M.g)) " *
    "cycle-rank=$(ne(M.g) - nv(M.g) + length(connected_components(M.g))) " *
    "tips=$(count(==(1), degree(M.g)))")
