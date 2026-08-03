# Generate the definition-slide drawing from a real Ball Mapper construction.
#
# Run from TDA_lecture_EBT2026:
#
#     julia --project=. scripts/make_ball_mapper_drawing.jl

using Random
using LinearAlgebra
using CairoMakie
using Graphs
using MetricSpaces
using TDAmapper

CairoMakie.activate!()

const FIGDIR = joinpath(@__DIR__, "..", "figures")
const BACKGROUND = RGBf(15 / 255, 15 / 255, 15 / 255)
const INK = RGBf(250 / 255, 250 / 255, 250 / 255)
const MUTED = RGBf(160 / 255, 160 / 255, 160 / 255)
const ORANGE = RGBf(1, 110 / 255, 0)
const PALE_ORANGE = RGBf(1, 211 / 255, 161 / 255)

# A noisy circle makes the topology visible without inventing the nerve by hand.
# FPS chooses the landmarks; ball_mapper computes both the cover and every edge.
Random.seed!(20260803)
n = 210
angles = range(0, 2pi; length = n + 1)[1:end-1]
radii = 2 .+ 0.07 .* randn(n)
X = permutedims(hcat(radii .* cos.(angles), radii .* sin.(angles)))
X .+= 0.025 .* randn(size(X))
space = EuclideanSpace(X)

Random.seed!(20260803)
landmarks = farthest_points_sample_ids(space, 7)
epsilon = 1.45
M = ball_mapper(space, landmarks, epsilon)

# These checks make the explanatory picture part of the same executable story as
# the data-derived plots: a covered circle whose Ball Mapper is one cycle.
@assert length(unique(vcat(M.C...))) == n
@assert nv(M.g) == length(landmarks) == 7
@assert ne(M.g) == 7
@assert all(==(2), degree(M.g))
@assert all(!isempty(intersect(M.C[src(e)], M.C[dst(e)])) for e in edges(M.g))

# In this sample one pair of geometric disks overlaps without containing a shared
# observation. Its missing graph edge illustrates the distinction made on-slide.
landmark_pairs = [(i, j) for i in eachindex(landmarks)
                  for j in (i + 1):length(landmarks)]
@assert any(landmark_pairs) do (i, j)
    LinearAlgebra.norm(X[:, landmarks[i]] - X[:, landmarks[j]]) < 2epsilon &&
        !has_edge(M.g, i, j)
end

points = [Point2f(X[1, i], X[2, i]) for i in axes(X, 2)]
landmark_points = points[landmarks]
memberships = zeros(Int, n)
for ball in M.C
    memberships[ball] .+= 1
end
shared = findall(>(1), memberships)

fig = Figure(size = (1440, 430), backgroundcolor = BACKGROUND)

for (column, label) in zip((1, 3, 5),
        ("01 · LANDMARKS", "02 · ε-BALLS", "03 · NERVE"))
    Label(fig[1, column], label;
        color = ORANGE, fontsize = 22, font = :bold,
        halign = :left, tellwidth = false)
end

axes_by_step = [Axis(fig[2, column];
    backgroundcolor = BACKGROUND, aspect = DataAspect()) for column in (1, 3, 5)]
for ax in axes_by_step
    hidedecorations!(ax)
    hidespines!(ax)
    xlims!(ax, -3.62, 3.62)
    ylims!(ax, -3.62, 3.62)
end
ax_landmarks, ax_balls, ax_nerve = axes_by_step

# Step 1: the metric data and farthest-point landmarks.
scatter!(ax_landmarks, points;
    color = RGBAf(INK.r, INK.g, INK.b, 0.72), markersize = 6)
scatter!(ax_landmarks, landmark_points;
    color = ORANGE, markersize = 20,
    strokecolor = INK, strokewidth = 1.4)

# Step 2: the actual EpsilonBall cover. Shared observations are highlighted.
for centre in landmark_points
    poly!(ax_balls, Circle(centre, epsilon);
        color = RGBAf(ORANGE.r, ORANGE.g, ORANGE.b, 0.12),
        strokecolor = RGBAf(ORANGE.r, ORANGE.g, ORANGE.b, 0.92),
        strokewidth = 2.2)
end
scatter!(ax_balls, points;
    color = RGBAf(INK.r, INK.g, INK.b, 0.58), markersize = 5.5)
scatter!(ax_balls, points[shared];
    color = PALE_ORANGE, markersize = 8,
    strokecolor = BACKGROUND, strokewidth = 0.7)
scatter!(ax_balls, landmark_points;
    color = ORANGE, markersize = 18,
    strokecolor = INK, strokewidth = 1.2)

# Step 3: draw only edges returned by TDAmapper's SimpleNerve.
segments = Point2f[]
for e in edges(M.g)
    push!(segments, landmark_points[src(e)], landmark_points[dst(e)])
end
linesegments!(ax_nerve, segments;
    color = RGBAf(INK.r, INK.g, INK.b, 0.88), linewidth = 3)
scatter!(ax_nerve, landmark_points;
    color = ORANGE, markersize = 25,
    strokecolor = INK, strokewidth = 1.5)

for column in (2, 4)
    Label(fig[2, column], "→";
        color = MUTED, fontsize = 42, tellwidth = true)
end

rowsize!(fig.layout, 1, 34)
rowsize!(fig.layout, 2, 370)
rowgap!(fig.layout, 7)
colgap!(fig.layout, 10)
for column in (1, 3, 5)
    colsize!(fig.layout, column, 370)
end
colsize!(fig.layout, 2, 42)
colsize!(fig.layout, 4, 42)

mkpath(FIGDIR)
output = joinpath(FIGDIR, "ball_mapper_explainer.png")
save(output, fig; px_per_unit = 2)
println("wrote $(basename(output)): $(nv(M.g)) nodes, $(ne(M.g)) edges, " *
        "$(length(shared)) shared observations")
