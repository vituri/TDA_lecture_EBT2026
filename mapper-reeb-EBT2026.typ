#import "@preview/touying:0.6.1": *
#import themes.metropolis: *
#import "@preview/cetz:0.5.2"

// ──────────────────────────────────────────────────────────────────────────
//  Palette: tied to the viridis colormap used by the actual Mapper plots
// ──────────────────────────────────────────────────────────────────────────
#let ink      = rgb("#22252e")
#let plum     = rgb("#2c2350")   // section / focus backgrounds
#let vpurple  = rgb("#440154")
#let vblue    = rgb("#3b528b")
#let vteal    = rgb("#21918c")   // primary accent
#let vgreen   = rgb("#5ec962")
#let vyellow  = rgb("#fde725")
#let paper    = rgb("#fcfcfe")
#let mist     = rgb("#eef2f3")

// ──────────────────────────────────────────────────────────────────────────
//  Theme
// ──────────────────────────────────────────────────────────────────────────
#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [The Mapper Algorithm],
    subtitle: [A discrete analogue of the Reeb graph],
    author: [Guilherme Vituri],
    date: [XXIV EBT · 2026],
    institution: [Symbolic Mind · JuliaTDA],
  ),
  config-colors(
    primary: plum,
    primary-light: vteal,
    secondary: vteal,
    neutral-lightest: paper,
    neutral-dark: ink,
    neutral-darkest: ink,
  ),
  config-common(
    datetime-format: auto,
  ),
)

// Modern typography
#set text(font: ("Lato", "Noto Sans"), weight: "regular")
#show math.equation: set text(font: "New Computer Modern Math")
#show raw: set text(font: ("DejaVu Sans Mono", "Liberation Mono"))
#show raw.where(block: true): set text(size: 0.74em)
#set par(justify: false)

// Small helpers ──────────────────────────────────────────────────────────
#let accent(body) = text(fill: vteal, weight: "bold", body)
// Bright emphasis for use on the dark focus slides (where *bold* would render dark)
#let bright(body) = text(fill: rgb("#5fd6c4"), weight: "bold", body)
#let hot(body) = text(fill: vyellow, weight: "bold", body)
#let chip(c, body) = box(
  fill: c, inset: (x: 6pt, y: 3pt), radius: 3pt,
  text(fill: white, weight: "bold", size: 0.8em, body),
)
#let card(body, fill: mist) = block(
  fill: fill, inset: 12pt, radius: 8pt, width: 100%, body,
)
#let cite-tag(body) = text(size: 0.72em, fill: gray, style: "italic", body)

// CeTZ shortcut
#let draw = cetz.draw
#let canvas = cetz.canvas

// ════════════════════════════════════════════════════════════════════════
#title-slide()

// ── The thesis ────────────────────────────────────────────────────────────
#focus-slide[
  #set text(size: 1.05em)
  Mapper is what is left of the #bright[Reeb graph] once you make it computable:
  swap _connected components of fibres_ for _cover + clustering_.

  #v(0.6em)
  #hot[The nerve lemma is what guarantees the result is a faithful shadow of the data.]
]

// ════════════════════════════════════════════════════════════════════════
= The Reeb graph

== A classical one-dimensional summary

Given a topological space $X$ and a continuous $f : X arrow.r RR$, the *Reeb graph*
collapses each connected component of every level set to a point:

#v(0.3em)
#align(center)[
  $ p tilde q quad <==> quad p, q "lie in the same connected component of" f^(-1)(c) $
]
#v(0.3em)

#grid(columns: (1.2fr, 1fr), gutter: 18pt,
  [
    *In the language topologists know:*
    - it is the quotient $X slash tilde$ of Morse theory;
    - critical points of $f$ become *vertices*; arcs track how components are
      born, merge, split, die;
    - a compact 1-D skeleton that *records the topology of the level sets*.
  ],
  card[
    #set align(center)
    #canvas(length: 0.85cm, {
      import draw: *
      // a stylised torus
      circle((0,0), radius: (1.5, 1.0), stroke: ink + 1.5pt)
      circle((0,0), radius: (0.7, 0.45), stroke: ink + 1.2pt)
      // height function arrow
      line((-2.3,-1.2), (-2.3,1.2), mark: (end: ">"), stroke: vteal + 1.5pt)
      content((-2.6,0), text(fill: vteal, size: 0.8em)[$f$], anchor: "east")
      // reeb graph (a loop = the hole) on the right
      let cx = 3.4
      bezier((cx, -1.1), (cx, 1.1), (cx - 0.9, 0), (cx - 0.9, 0), stroke: vpurple + 2pt)
      bezier((cx, -1.1), (cx, 1.1), (cx + 0.9, 0), (cx + 0.9, 0), stroke: vpurple + 2pt)
      for p in ((cx, -1.1), (cx, 1.1)) { circle(p, radius: 0.12, fill: vpurple, stroke: white+1pt) }
      circle((cx - 0.9, 0), radius: 0.1, fill: vyellow, stroke: white+1pt)
      circle((cx + 0.9, 0), radius: 0.1, fill: vyellow, stroke: white+1pt)
    })
    #cite-tag[Torus + height $arrow.r$ a loop (the hole). Reeb 1946.]
  ],
)

== Why we cannot just compute it

In the real world, we almost never have $X$. We have a *finite sample* of it: a point cloud.

#v(0.4em)
#grid(columns: (1fr, 1fr), gutter: 16pt,
  card(fill: rgb("#fbeaea"))[
    #text(fill: rgb("#a33"))[*The obstruction*]
    - "Connected component" is *trivial* on a finite set: every point is its own.
    - "Level set $f^(-1)(c)$" is *empty* for almost every $c$.
  ],
  card(fill: rgb("#eaf4f3"))[
    #text(fill: vteal)[*The fix (next part)*]
    - replace connected components by *clustering*.
    - replace points $c$ by *intervals* covering $f(X)$;
  ],
)
#v(0.3em)
This is exactly the move Singh, Mémoli & Carlsson made in 2007. #cite-tag[PBG\@Eurographics 2007]

// ════════════════════════════════════════════════════════════════════════
= Mapper

== From continuous to discrete

#table(
  columns: (1.1fr, 1fr, 1.1fr),
  inset: 9pt, align: (left, center, left), stroke: 0.5pt + mist.darken(8%),
  table.header(
    [*Reeb (continuous)*], [], [*Mapper (discrete)*],
  ),
  [topological space $X$], chip(vteal)[becomes], [finite metric space $(X,d)$],
  [continuous $f : X arrow.r RR$], chip(vteal)[becomes], [any $f : X arrow.r RR$ (auto-continuous)],
  [preimage of a *point* $c$], chip(vteal)[becomes], [preimage of an *interval* $U$],
  [*connected components*], chip(vteal)[becomes], [*clusters* (DBSCAN, single-linkage…)],
)

#v(0.5em)
#align(center)[
  #text(fill: plum, weight: "bold")[Three ingredients:]
  #h(0.6em) a filter $f$ #h(0.4em)·#h(0.4em) a cover $C$ of $f(X)$ #h(0.4em)·#h(0.4em) a clustering rule
]

== The pipeline

#v(0.8em)
#grid(columns: (1fr, auto, 1fr, auto, 1fr), align: center + horizon, column-gutter: 4pt,
  [
    #align(center)[#text(weight: "bold", fill: plum, size: 0.85em)[① cover $f(X)$]]
    #v(6pt)
    #align(center)[#canvas(length: 0.65cm, {
      import draw: *
      line((-1.4, 0), (1.4, 0), stroke: ink + 1pt)
      let iv = ((-1.3, -0.3, vpurple), (-0.4, 0.6, vteal), (0.5, 1.3, vgreen))
      let k = 0
      for it in iv {
        rect((it.at(0), 0.3 + k*0.3), (it.at(1), 0.55 + k*0.3), fill: it.at(2).lighten(12%), stroke: none)
        k += 1
      }
    })]
  ],
  text(fill: gray, size: 1.4em)[→],
  [
    #align(center)[#text(weight: "bold", fill: plum, size: 0.85em)[② pull back + cluster]]
    #v(6pt)
    #align(center)[#canvas(length: 0.65cm, {
      import draw: *
      circle((-0.8, 0.3), radius: 0.55, fill: vpurple.lighten(30%), stroke: none)
      circle((0.3, 0.55), radius: 0.62, fill: vteal.lighten(30%), stroke: none)
      circle((0.2, -0.6), radius: 0.5, fill: vteal.lighten(45%), stroke: none)
      circle((1.2, 0.2), radius: 0.55, fill: vgreen.lighten(30%), stroke: none)
    })]
  ],
  text(fill: gray, size: 1.4em)[→],
  [
    #align(center)[#text(weight: "bold", fill: plum, size: 0.85em)[③ nerve graph]]
    #v(6pt)
    #align(center)[#canvas(length: 0.65cm, {
      import draw: *
      let n = ((-0.9, 0.2, vpurple), (0.1, 0.6, vteal), (0.0, -0.5, vteal), (1.1, 0.1, vgreen))
      line(n.at(0).slice(0, 2), n.at(1).slice(0, 2), stroke: gray + 1.5pt)
      line(n.at(1).slice(0, 2), n.at(2).slice(0, 2), stroke: gray + 1.5pt)
      line(n.at(1).slice(0, 2), n.at(3).slice(0, 2), stroke: gray + 1.5pt)
      for v in n { circle(v.slice(0, 2), radius: 0.2, fill: v.at(2), stroke: white + 1.2pt) }
    })]
  ],
)

#v(0.9em)
- *Nodes* = clusters of points; their *colour* summarises a value over those points.
- *Edges* = clusters that *share a point*; this is the 1-dimensional nerve:
  #h(0.5em) $(v_1, v_2) in E #h(0.3em) <==> #h(0.3em) v_1 inter v_2 != emptyset$.

== The hinge: the nerve lemma

#card(fill: rgb("#eaf4f3"))[
  *Nerve lemma.* If a cover is *good* (every nonempty intersection is contractible),
  the nerve is *homotopy-equivalent* to the union. The combinatorial graph is a
  faithful shadow of the space.
]

#v(0.5em)
#grid(columns: (1fr, 0.9fr), gutter: 16pt,
  [
    This is the *one idea* behind everything that follows:

    #align(center)[#text(fill: plum, weight: "bold", size: 1.05em)[
      everything is the nerve of a cover;\ only the cover changes.
    ]]

    - Mapper: nerve of a *pullback* cover.
    - Ball Mapper: nerve of a cover by *balls*.
    - Multiscale: a *tower* of nerves.
  ],
  align(center + horizon)[
    #canvas(length: 0.9cm, {
      import draw: *
      circle((0,0), radius: 0.95, fill: vpurple.transparentize(60%), stroke: vpurple+1pt)
      circle((1.1,0), radius: 0.95, fill: vteal.transparentize(60%), stroke: vteal+1pt)
      circle((0.55,-0.95), radius: 0.95, fill: vgreen.transparentize(60%), stroke: vgreen+1pt)
      // nerve = triangle
      let a=(0,0); let b=(1.1,0); let c=(0.55,-0.95)
      line(a,b, stroke: ink+1.5pt); line(b,c, stroke: ink+1.5pt); line(a,c, stroke: ink+1.5pt)
      for p in (a,b,c) { circle(p, radius:0.13, fill: ink, stroke: white+1pt) }
    })
  ],
)

== A worked example: the torus

#grid(columns: (1.02fr, 1fr), gutter: 16pt,
  [
    $4000$ points on a torus, $f = $ height above the plane of the donut, uniform
    overlapping intervals, DBSCAN per slice.

    #v(0.3em)
    #card[
      ```julia
      using TDAmapper, TDAplots, MetricSpaces
      using TDAmapper.ImageCovers,
            TDAmapper.IntervalCovers,
            TDAmapper.Refiners
      using MetricSpaces.Datasets: torus

      X = torus(4000)
      f = [x[3] for x in X]        # filter

      C = R1Cover(f,
            Uniform(length = 8, expansion = 0.3))
      M = classical_mapper(X, C,
            DBscan(radius = 0.8, min_cluster_size = 5))

      mapper_plot(M,
          node_values = node_colors(M, f))
      ```
    ]
  ],
  align(center + horizon)[
    #image("figures/torus_mapper.png", width: 100%)
    #cite-tag[
      $14$ nodes, $14$ edges, every node of degree $2$: a single cycle. The same
      shadow the Reeb graph gave us, recovered from a finite sample.
    ]
  ],
)

// ════════════════════════════════════════════════════════════════════════
= Variations & stability

== Ball Mapper: drop the filter, keep a scale

No filter function at all: cover $X$ by $epsilon$-balls around landmarks
$L subset X$, then take the nerve.

#v(0.3em)
#grid(columns: (1.1fr, 1fr), gutter: 16pt,
  [
    #align(center)[$ (i,j) in E #h(0.3em) <==> #h(0.3em) B(x_i, epsilon) inter B(x_j, epsilon) != emptyset $]
    #v(0.3em)
    - the 1-skeleton of a *Vietoris–Rips*-flavoured complex, centred on landmarks;
    - one knob, the radius $epsilon$, instead of a filter + cover + clustering;
    - *contrast:* #accent[Mapper needs a good filter; Ball Mapper trades the filter for a scale.]
    #v(0.2em)
    #cite-tag[Dłotko 2019, arXiv:1901.07410.]
  ],
  align(center + horizon)[
    #canvas(length: 0.8cm, {
      import draw: *
      let n = 14
      let pts = ()
      for i in range(n) {
        let a = 2*calc.pi*i/n
        pts.push((2.1*calc.cos(a), 2.1*calc.sin(a)))
      }
      // epsilon balls
      for p in pts { circle(p, radius: 0.55, fill: vteal.transparentize(80%), stroke: vteal.transparentize(40%)+0.6pt) }
      // nerve cycle
      for i in range(n) { line(pts.at(i), pts.at(calc.rem(i+1,n)), stroke: gray.lighten(20%)+1.5pt) }
      for p in pts { circle(p, radius: 0.14, fill: vpurple, stroke: white+1pt) }
    })
    #cite-tag[Ball Mapper of a circle $arrow.r$ recovers $S^1$.]
  ],
)

== Making "statistical" honest

Mapper is *deterministic* given its parameters. _Statistical_ earns its place
through three distinct results:

#v(0.3em)
#grid(columns: 3, gutter: 12pt,
  card[
    #chip(vpurple)[sample] #v(0.3em)
    Run on a *sample*, not on $X$ itself.
  ],
  card[
    #chip(vteal)[converge] #v(0.3em)
    *Converges to the Reeb graph* as the sample grows. #cite-tag[Munch–Wang 2016]
  ],
  card[
    #chip(vgreen)[infer] #v(0.3em)
    *Parameter choice + bootstrap.* #cite-tag[Carrière–Michel–Oudot 2018]
  ],
)

#v(0.5em)
#card(fill: rgb("#eaf4f3"))[
  *Structure & stability of the 1-D Mapper* (Carrière–Oudot, FoCM 2018): the
  Mapper of a Morse-type function is provably *close* to its Reeb graph: small
  data perturbations move it only a little. #accent[This is the theorem that lets us
  trust the picture.]
]

// ════════════════════════════════════════════════════════════════════════
= Generalizing Mapper

== Two steps, two knobs

Strip Mapper to its skeleton and *every* variant is the same two moves:

#v(0.4em)
#grid(columns: (1fr, 1fr), gutter: 16pt,
  card(fill: rgb("#f3eefa"))[
    #text(fill: vpurple, weight: "bold")[① Covering step]
    Given $(X,d)$, build a cover $C$ of $X$.
    - classical: cluster pullbacks of a filter;
    - ball: $epsilon$-balls around landmarks;
    - adaptive: ball of radius $epsilon$, but if it holds $< n$ points, take the
      $n$ nearest neighbours;
    - scale-free: radius $lambda dot d_l$, with $d_l$ the nearest-neighbour distance.
  ],
  card(fill: rgb("#eaf4f3"))[
    #text(fill: vteal, weight: "bold")[② Nerve step]
    With $C$ as vertices, build a graph.
    - usual nerve: edge iff $a inter b != emptyset$;
    - thresholded: edge iff $|a inter b| >= k$
      #h(0.3em) ($k = 1$ recovers the nerve);
    - higher nerves, weighted edges, …
  ],
)

#v(0.3em)
#align(center)[#cite-tag[`ball_mapper_generic` in TDAmapper.jl lets you swap either step.]]

== Bigger axes of generalization

#grid(columns: (1fr, 1fr), gutter: 14pt, row-gutter: 12pt,
  card[
    #chip(vblue)[multiscale]
    *Multiscale Mapper*: cover the codomain at many scales $arrow.r$ a *tower* of
    Mappers, with stability by *interleaving*. #cite-tag[Dey–Mémoli–Wang, SODA 2016]
  ],
  card[
    #chip(vpurple)[codomain]
    *Change the filter's target:* $f arrow.r S^1$ (circular coordinates),
    $arrow.r$ a graph, $arrow.r RR^d$, the *Reeb space* / multivariate Mapper.
  ],
  card[
    #chip(vteal)[structure]
    *Structure & stability of 1-D Mapper*: the clean theorem that makes all of
    this rigorous. #cite-tag[Carrière–Oudot, FoCM 2018]
  ],
  card(fill: rgb("#fff7e0"))[
    #chip(vyellow)[learn]
    *Differentiable Mapper*: what if the filter were not chosen, but
    *learned*? #h(0.2em) (next slide → the climax)
  ],
)

== Climax: Differentiable Mapper

#align(center)[#text(fill: plum, weight: "bold", size: 1.0em)[
  Reeb *fixes* the filter. Mapper *chooses* it. Differentiable Mapper *learns* it.
]]

#v(0.4em)
#grid(columns: (1.04fr, 0.96fr), gutter: 18pt,
  [
    Optimise the filter $theta$ by *gradient descent* on a topological loss
    #cite-tag[Oulhaj–Carrière–Michel, ICML 2024]. Implemented in *TDAmapper.jl*.

    - *soft cover*: smooth membership $arrow.r$ hard cover as $s arrow.r infinity$;
    - *differentiable persistence*: pairing frozen (`@ignore_derivatives`);
      diagram *values* carry the gradient;
    - loss = total *extended* persistence; `Zygote` + `Optimisers.Adam`;
    - #accent[Julia's native autodiff is the structural win.]
  ],
  [
    #align(center)[#canvas(length: 0.72cm, {
      import draw: *
      // a tent / Λ shape, with a bad filter line rotating to a good one
      line((-1.4, -0.9), (0, 1.4), stroke: ink + 1.5pt)
      line((0, 1.4), (1.4, -0.9), stroke: ink + 1.5pt)
      // bad filter (horizontal-ish)
      line((-1.8, -0.4), (1.8, 0.2), stroke: (paint: gray, thickness: 1.5pt, dash: "dashed"))
      content((2.0, 0.2), text(size: 0.7em, fill: gray)[$theta_0$], anchor: "west")
      // good filter (vertical = height)
      line((0, -1.3), (0, 1.7), mark: (end: ">"), stroke: vteal + 2pt)
      content((0.2, 1.7), text(size: 0.7em, fill: vteal)[$theta^*$], anchor: "west")
      // gradient arrow
      arc((1.4, -0.2), start: -10deg, stop: 70deg, radius: 1.0, mark: (end: ">"), stroke: vyellow.darken(15%) + 2pt)
      content((1.9, 0.9), text(size: 0.7em, fill: vyellow.darken(25%))[$nabla_theta$], anchor: "west")
    })]
    #v(0.5em)
    #card(fill: rgb("#eaf4f3"))[
      #set text(size: 0.92em)
      #text(fill: vteal)[*Loop-aware by default.*] Ordinary $0$-D persistence sees
      branches, not loops: on a *cycle* the loss is *identically zero*, so there is no
      gradient at all. So the default loss is *extended* persistence
      ($"Ord"_0 + "Ext"_0 + "Ext"_1$), which is strictly positive on a loop.
    ]
  ],
)

// ════════════════════════════════════════════════════════════════════════
= Applications

== The shape of data

#grid(columns: (1fr, 1fr), gutter: 16pt,
  [
    Lum et al. used Mapper to extract insight from the *shape* of complex data:
    #cite-tag[Lum et al., Scientific Reports 2013]
    - *breast-cancer* survival subgroups,
    - *congressional voting* structure,
    - *NBA* player data.

    #v(0.3em)
    The basketball result, *"from 5 to 13" positions*, is Alagappan's, using the
    same Mapper engine (Ayasdi). #cite-tag[Alagappan, MIT Sloan 2012]
  ],
  [
    #card(fill: rgb("#eaf4f3"))[
      #text(fill: vteal, weight: "bold")[Why Mapper, not a scatter?]
      #v(0.3em)
      PCA / UMAP *compress* overlapping styles into one cloud. Mapper keeps the
      *continuous structure* and turns local groups into *branches*, and the
      branches carry the story.
    ]
    #v(0.4em)
    // PLACEHOLDER: drop in Alagappan's NBA Mapper figure (MIT Sloan 2012, Fig. 3)
    // or the Lum et al. 2013 breast-cancer graph, with the citation already below.
    #block(fill: mist, inset: 10pt, radius: 6pt, width: 100%)[
      #set align(center)
      #text(size: 0.8em, fill: gray.darken(20%))[
        #emph[figure slot]: Alagappan's NBA graph \
        #text(size: 0.85em)[(paste the published figure here)]
      ]
    ]
  ],
)

== Football: one filter, and what branches off it

#set text(size: 0.8em)
#grid(columns: (1fr, 1.22fr), gutter: 12pt,
  [
    $1513$ outfield players, big-five leagues, *2020–21*; $18$ z-scored per-90
    features. Filter $=$ PC#sub[1] ($45.5%$ of variance), $14$ intervals, DBSCAN
    per slice. #cite-tag[FBref-derived snapshot]

    #v(0.2em)
    - *Not a blob:* a defensive chain, an attacking region, joined through
      midfield.
    - Mapper was *never told the positions*; node purity #accent[$0.67$] vs. a
      #accent[$0.463$] largest-group baseline.
    - The *tips* are specialists: Benzema, a pure scorer; and a
      scorer-*and*-creator tip with #accent[Mbappé, Neymar, De Bruyne], the
      playmaking maximum.
    - #accent[Lewandowski and Messi] are a *two-player* isolated node, Muriel a
      one-player one: outliers, not archetypes.
  ],
  align(center + horizon)[
    #image("figures/soccer_named.png", width: 100%)
    #cite-tag[$22$ nodes · area $prop$ cluster size · colour $=$ dominant
      position, which is a tie in $3$ of the $22$.]
  ],
)

== One graph, many stories

Mapper's real strength for exploration: *recolour the same nodes*, keeping the same graph
and layout while changing the variable.

#v(0.3em)
#grid(columns: 3, gutter: 10pt,
  [
    #image("figures/soccer_goals.png", width: 100%)
    #align(center)[#chip(vyellow.darken(20%))[goals]]
  ],
  [
    #image("figures/soccer_defense.png", width: 100%)
    #align(center)[#chip(vpurple)[defending]]
  ],
  [
    #image("figures/soccer_playmaking.png", width: 100%)
    #align(center)[#chip(vteal)[playmaking]]
  ],
)

#v(0.1em)
#card(fill: rgb("#eaf4f3"))[
  #set text(size: 0.85em)
  Goals and defending are #bright[mirror images]: the two ends of the axis the
  filter found. #accent[Playmaking is not:] flat along that axis, spiking on a
  *tip*. That peak is *off-filter* structure, which a PC#sub[1] scatter flattens away.
]

== Where do the Brazilians sit?

#set text(size: 0.88em)
#grid(columns: (1fr, 1.05fr), gutter: 14pt,
  [
    $72$ of $1513$ players are Brazilian, a #accent[$4.8%$] base rate.

    #v(0.2em)
    - The share is *broadly uniform*. No node is "the Brazilian cluster"; the
      honest reading is that they are spread across the whole shape.
    - What is worth pointing at is *where the named ones land*: #accent[Neymar] on
      the scorer-and-creator tip beside Mbappé; #accent[Rodrygo] and
      #accent[Gabriel Jesus] in the attacking midfield; #accent[Casemiro] and
      #accent[Fernando] deep among the defenders; #accent[Thiago Silva] on the
      defensive tip.
    - Both extremes *and* the middle: itself an answer.
  ],
  align(center + horizon)[
    #image("figures/soccer_brazil.png", width: 100%)
    #cite-tag[Colour $=$ fraction Brazilian in each node.]
  ],
)

== Change the filter, change the question

#set text(size: 0.8em)
Same cover ($20$ intervals, expansion $0.6$), same DBSCAN. *Only the filter moves.*

#v(0.25em)
#grid(columns: 4, gutter: 7pt, align: center,
  [
    #image("figures/filter_pc1.png", width: 100%)
    #text(size: 0.95em)[*PC#sub[1]*]
    #cite-tag[$49$ nodes, $68$ edges \ $6$ comps, $12$ tips]
  ],
  [
    #image("figures/filter_attack.png", width: 100%)
    #text(size: 0.95em)[*xG $+$ xA*]
    #cite-tag[$49$ nodes, $76$ edges \ $3$ comps, $8$ tips]
  ],
  [
    #image("figures/filter_ecc.png", width: 100%)
    #text(size: 0.95em)[*eccentricity*]
    #cite-tag[$52$ nodes, $58$ edges \ $7$ comps, $26$ tips]
  ],
  [
    #image("figures/filter_dens.png", width: 100%)
    #text(size: 0.95em)[*kNN density*]
    #cite-tag[$24$ nodes, $12$ edges \ $12$ comps, $8$ isolated]
  ],
)

#v(0.15em)
#card[
  #set text(size: 0.92em)
  PC#sub[1] and xG$+$xA give the *same $49$ nodes*, with $68$ vs $76$ edges, $6$ vs
  $3$ components, $12$ vs $8$ tips. Same resolution, different shape: the
  #accent[filter] is doing the work, not the cover. Density fails outright:
  $1113$ of $1513$ players in *one* node, because kNN density is nearly constant
  on the bulk, so its level sets separate nothing.
]

== Where the flares come from

#set text(size: 0.84em)
#grid(columns: (1fr, 1.4fr), gutter: 12pt,
  [
    Filter $=$ *eccentricity*, the mean distance to every other player. Its level
    sets are *shells* around the dense core.

    #v(0.2em)
    - Extremes in *different directions* therefore share a slice, and the
      clustering pulls them apart: #accent[$27$ of $51$ nodes are degree-$1$ tips].
    - The flares end in *individuals*: Messi, Lewandowski and De Bruyne each
      alone in a node of their own; Mbappé and Haaland share a five-player one.
    - The core is two nodes of $581$ and $564$ players, carrying most of the
      spokes. $7$ components: some flares detach completely.
  ],
  align(center + horizon)[#image("figures/soccer_ecc.png", width: 100%)],
)

#v(0.1em)
#card(fill: rgb("#fbeaea"))[
  #set text(size: 0.85em)
  #text(fill: rgb("#a33"))[*The lens makes the shape.*] A centrality filter
  produces flares *by construction*, so "look, flares" is weaker evidence here
  than the same structure under a filter chosen for meaning. Read this as
  #emph[who is atypical], not as #emph[the data is a starfish].
]

== Two lenses: what one filter cannot do

#set text(size: 0.82em)
#grid(columns: (1.45fr, 1fr), gutter: 12pt,
  align(center + horizon)[#image("figures/soccer_2lens.png", width: 100%)],
  [
    `R2Cover(PC₁, PC₂)`: a $12 times 12$ grid of cells.
    #accent[$146$ nodes, $390$ edges, cycle rank $252$], and purity rises to
    $0.82$.

    #v(0.3em)
    *Why it looks different.* With *one* filter and expansion $< 1$ only adjacent
    slices meet, and the clusters inside a slice are disjoint. So
    #align(center)[$"node" |-> "its slice"$]
    is a graph homomorphism onto a *path*, making the graph *bipartite* and
    *triangle-free*.

    #v(0.3em)
    A grid cover has $(i,j)$ meeting $(i+1,j+1)$: the target is the *king graph*
    on $ZZ^2$, which has triangles.
  ],
)

#v(0.1em)
#card[
  #set text(size: 0.88em)
  Checked: one filter gives #accent[$0$ triangles] at expansion $0.2$, $0.4$, $0.8$
  for DBSCAN, histogram-gap *and* trivial refiners alike. This graph has
  #accent[$322$]. So the web is not a tuning achievement: a $1$-D filter
  #emph[cannot] produce it.
]

== One knob at a time: overlap

#set text(size: 0.82em)
`Uniform` centres intervals one step apart with radius $("step"\/2)(1 + e)$.
Slices $i$ and $i+2$ sit two steps apart, so they first meet exactly when
#accent[$e > 1$].

#v(0.25em)
#grid(columns: 3, gutter: 9pt, align: center,
  [
    #image("figures/overlap_04.png", width: 100%)
    #text(size: 0.95em)[$e = 0.4$]
    #cite-tag[$29$ edges · cycle rank $7$ · $0$ triangles]
  ],
  [
    #image("figures/overlap_10.png", width: 100%)
    #text(size: 0.95em)[$e = 1.0$ #text(size: 0.8em)[(boundary)]]
    #cite-tag[$37$ edges · cycle rank $10$ · $0$ triangles]
  ],
  [
    #image("figures/overlap_14.png", width: 100%)
    #text(size: 0.95em)[$e = 1.4$]
    #cite-tag[$74$ edges · cycle rank $43$ · $47$ triangles]
  ],
)

#v(0.15em)
#card[
  #set text(size: 0.9em)
  Crossing the threshold *doubles the edges* and takes the cycle rank from $7$ to
  $43$. Below it the graph is a layered, Reeb-like object; above it, edges jump
  between non-adjacent level sets and #accent[that reading is gone]. The loops
  you would go on to measure are artefacts of the cover, not of the data.
]

== The nerve is a choice too

#set text(size: 0.84em)
#grid(columns: (1fr, 1fr, 1.5fr), gutter: 11pt, align: horizon,
  [
    #image("figures/nerve_simple.png", width: 100%)
    #align(center)[#text(size: 0.95em)[*any* shared player]]
  ],
  [
    #image("figures/nerve_jaccard.png", width: 100%)
    #align(center)[#text(size: 0.95em)[Jaccard $>= 0.1$]]
  ],
  [
    The two-lens graph again: *same cover, same clusters, same $146$ nodes, same
    purity $0.82$*. Only the rule for drawing an *edge* changed.

    #v(0.3em)
    - $390 -> #text(fill: vteal, weight: "bold")[213]$ edges;
    - cycle rank $252 -> #text(fill: vteal, weight: "bold")[85]$;
    - components $8 -> 18$.

    #v(0.3em)
    Requiring a *substantial* overlap rather than one shared player removes most of
    the homology, and the loop still plainly visible on the right is one of the
    #accent[$85$ that survive] instead of one of $252$. Thresholding the nerve is
    how you find out which cycles were overlap noise.
    #cite-tag[`Nerves`: Simple, MinCount, Percentage, Jaccard]
  ],
)

== Does the story survive the parameters?

#set text(size: 0.85em)
The cover and the clustering are *choices*. Change the resolution:

#v(0.2em)
#grid(columns: 3, gutter: 8pt, align: center,
  [
    #image("figures/soccer_coarse.png", width: 100%)
    #text(size: 0.85em)[*coarse*: 12 nodes]
  ],
  [
    #image("figures/soccer_position.png", width: 100%)
    #text(size: 0.85em)[*as read*: 22 nodes]
  ],
  [
    #image("figures/soccer_fine.png", width: 100%)
    #text(size: 0.85em)[*fine*: 45 nodes]
  ],
)

#v(0.1em)
#card(fill: rgb("#fbeaea"))[
  #set text(size: 0.88em)
  #text(fill: rgb("#a33"))[*Be honest.*] Coarsen and the branches vanish, leaving a pure
  defender#[--]midfield#[--]forward *path*. Refine and it fragments into $5$
  components. The *ordering of roles* is stable; the *branch structure is not*.
  #accent[And note what the stability theory does #emph[not] cover:] Carrière#[--]Oudot
  bounds perturbations of the *data* at a #emph[fixed] cover. Changing the cover
  is outside its hypotheses. This is exactly why *choosing* the cover is the
  open problem.
]

== Ball Mapper: throw the filter away

#set text(size: 0.82em)
#grid(columns: (1fr, 1fr, 1.5fr), gutter: 11pt, align: horizon,
  [
    #image("figures/ball_30.png", width: 100%)
    #align(center)[#text(size: 0.95em)[$epsilon = 3.0$]]
    #align(center)[#cite-tag[$186$ edges · $39$ comps]]
  ],
  [
    #image("figures/ball_36.png", width: 100%)
    #align(center)[#text(size: 0.95em)[$epsilon = 3.6$]]
    #align(center)[#cite-tag[$760$ edges · cycle rank $673$]]
  ],
  [
    $100$ farthest-point landmarks, balls of radius $epsilon$, *no filter at all*.

    #v(0.25em)
    - At $3.0$: *dust*, with $36$ of the $100$ landmarks isolated.
    - At $3.6$: *hairball*, with $673$ independent cycles.
    - There is no useful window in between.

    #v(0.25em)
    In $18$ dimensions the pairwise distances *concentrate*: the $5$th percentile
    is $2.52$, the $25$th only $3.88$. A single global radius has to separate
    scales that are barely separated.
  ],
)

#v(0.1em)
#card[
  #set text(size: 0.9em)
  Ball Mapper's virtue is having *no filter to choose*; the price is that the one
  remaining knob carries all the weight. #accent[Here that is an argument for the
  filter]: a lens contributes the very thing a global radius lacks, a direction
  along which "nearby" is allowed to mean different things.
]

// ════════════════════════════════════════════════════════════════════════
= Closing

== The arc, in one line

#focus-slide[
  #set text(size: 0.95em)
  Reeb #bright[fixes] the filter · Mapper #bright[chooses] it · Differentiable Mapper #bright[learns] it.

  #v(0.5em)
  #hot[And throughout, everything is the nerve of a cover.]
]

== Open problems & the JuliaTDA stack

#grid(columns: (1fr, 1fr), gutter: 16pt,
  card[
    #text(fill: plum, weight: "bold")[Open problems]
    - *nonlinear* trainable filters, from a linear $theta$ to a small network;
    - principled, data-driven *cover selection*: stability bounds data
      perturbations at a fixed cover, so the *choice of cover* (the sensitivity
      we just saw) is still unaccounted for. #cite-tag[bootstrap: Carrière–Michel–Oudot]
  ],
  card(fill: rgb("#eaf4f3"))[
    #text(fill: vteal, weight: "bold")[JuliaTDA]
    `TDAmapper.jl` · `MetricSpaces.jl` · `Ripserer.jl` · `PersistenceInference.jl`
    #v(0.3em)
    Fast, composable, native autodiff. #h(0.2em) #accent[github.com/JuliaTDA]
  ],
)

== References

#set text(size: 0.9em)
#set par(spacing: 0.85em)
#v(0.3em)
- Reeb, G. (1946). *Sur les points singuliers d'une forme de Pfaff…* C. R. Acad. Sci. Paris *222*, 847–849.
- Singh, Mémoli, Carlsson (2007). *Topological Methods for the Analysis of High-Dimensional Data Sets and 3D Object Recognition.* PBG\@Eurographics, 91–100.
- Lum et al. (2013). *Extracting insights from the shape of complex data using topology.* Scientific Reports *3*, 1236.
- Alagappan, M. (2012). *From 5 to 13: Redefining the Positions in Basketball.* MIT Sloan Sports Analytics Conf.
- Munch, Wang (2016). *Convergence between categorical representations of Reeb space and Mapper.* SoCG.
- Dey, Mémoli, Wang (2016). *Multiscale Mapper.* SODA.
- Carrière, Oudot (2018). *Structure and Stability of the One-Dimensional Mapper.* FoCM *18*, 1333–1396.
- Carrière, Michel, Oudot (2018). *Statistical Analysis and Parameter Selection for Mapper.* JMLR.
- Oulhaj, Carrière, Michel (2024). *Differentiable Mapper for Topological Optimization of Data Representation.* ICML.
- Dłotko, P. (2019). *Ball mapper: a shape summary for topological data analysis.* arXiv:1901.07410.

==

#focus-slide[
  #text(size: 1.6em, fill: white, weight: "bold")[Obrigado!]
  #v(0.5em)
  #text(size: 0.62em, fill: white.transparentize(10%))[
    Guilherme Vituri #h(0.4em)·#h(0.4em) Symbolic Mind #h(0.4em)·#h(0.4em) viturivituri\@gmail.com
  ]
]
