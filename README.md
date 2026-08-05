# The Mapper Algorithm

<p align="center">
  <a href="https://xxivebt.wixsite.com/ebt2026">
    <img src="assets/xxiv-ebt-logo.png" alt="XXIV Encontro Brasileiro de Topologia" width="180">
  </a>
</p>

<p align="center">
  <strong>A discrete analogue of the Reeb graph</strong><br>
  Guilherme Vituri · XXIV Encontro Brasileiro de Topologia · Vitória, 2026
</p>

How can we recover the shape of a space when all we have is a finite cloud of
data points?

This talk introduces **Mapper**, a method from topological data analysis that
turns complex, high-dimensional data into a graph. The graph is small enough to
explore visually, but rich enough to expose features such as branches, loops,
transitions, and unusual subgroups that ordinary two-dimensional projections
can hide.

The central idea is that Mapper is what remains of the **Reeb graph** once we
make it computable: instead of following exact level sets and their connected
components, we use overlapping regions and clustering. Their nerve records how
the resulting pieces intersect.

## What the talk covers

We begin with the Reeb graph of a torus and watch its topology emerge as a
height function sweeps across the surface. This provides the geometric intuition
for Mapper and explains why the classical construction cannot be applied
directly to a finite sample.

From there, the talk develops Mapper as a sequence of modelling decisions:

- **The filter determines the question.** Height, distance from a landmark,
  eccentricity, and geodesic distance can reveal very different structures in
  the same point cloud.
- **The cover determines the scale.** Resolution and overlap control which
  features are merged, separated, or created by the construction.
- **Clustering determines the nodes.** Different ways of splitting each region
  can change the branches of the graph.
- **The nerve determines the connections.** Even the rule used to draw an edge
  carries assumptions about what counts as meaningful overlap.

The talk also introduces **Ball Mapper**, which covers the data directly without
a filter, and **Differentiable Mapper**, which can learn a filter by optimizing a
topological objective. A controlled example shows a learned direction recovering
the four legs of a table when principal component analysis sees only its broad
surface.

A historical gallery uses original figures from eight landmark applications:
RNA folding pathways, two breast-cancer studies, congressional voting, NBA
playing roles, type-2 diabetes stratification, neurotrauma outcomes, and
single-cell differentiation. Each slide states the question, the published
finding, and a direct link to the source paper.

## The main case study: the shape of football

The second half of the talk applies Mapper to 1,513 outfield players from the
2020–21 seasons of Europe's five major leagues. Each player is represented by 18
standardized performance features, with no position labels given to Mapper.

The resulting graph organizes players along a broad progression from defence,
through midfield, to attack, while specialist roles appear as branches. By
recolouring the same graph, we can ask where goals, defensive actions,
playmaking, and Brazilian players sit within that shape.

This example is also a stress test. We change the filter, clustering method,
cover resolution, overlap, lens dimension, and edge rule to see which conclusions
survive. The broad ordering of roles is persistent; many individual branches,
loops, and components are not.

## The takeaway

Mapper is not a machine that reveals the one true shape of a dataset. It is a
way to ask a topological question of the data, and its answer depends on how that
question is posed.

> **The picture is an argument, never the conclusion.**

The goal of the talk is therefore both constructive and critical: to explain
why Mapper works, show what it can reveal, and make its modelling choices
visible rather than treating the final graph as self-explanatory.

## Who is this talk for?

The talk should be useful if you are interested in topology, data analysis,
machine learning, scientific visualization, or interpretable summaries of
high-dimensional data. Familiarity with basic topology is helpful, but no prior
knowledge of Mapper or topological data analysis is assumed.

## Talk materials

- [Interactive presentation](docs/index.html)
- [PDF slides](mapper-reeb-EBT2026.pdf)
- [Talk abstract](abstract-XXIV-EBT.tex)
- [XXIV EBT website](https://xxivebt.wixsite.com/ebt2026)

The examples were produced with the open-source
[JuliaTDA](https://github.com/JuliaTDA) ecosystem, including
[`TDAmapper.jl`](https://github.com/JuliaTDA/TDAmapper.jl).
