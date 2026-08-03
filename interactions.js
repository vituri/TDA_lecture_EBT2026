(() => {
  "use strict";

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

  function swapImage(image, source) {
    if (!image || image.getAttribute("src") === source) return;
    image.classList.add("swapping");
    window.setTimeout(() => {
      image.src = source;
      image.classList.remove("swapping");
    }, 110);
  }

  function setupButtonDemos() {
    $$('[data-demo="buttons"]').forEach((demo) => {
      const image = $("[data-demo-image]", demo);
      const caption = $("[data-demo-caption]", demo);
      const buttons = $$('button[data-src]', demo);

      buttons.forEach((button) => {
        button.addEventListener("click", () => {
          buttons.forEach((item) => item.classList.remove("active"));
          button.classList.add("active");
          swapImage(image, button.dataset.src);
          if (caption) caption.innerHTML = button.dataset.caption || "";
        });
      });
    });
  }

  function setupRangeDemos() {
    $$('[data-demo="range"]').forEach((demo) => {
      const range = $('input[type="range"]', demo);
      const image = $("[data-demo-image]", demo);
      const caption = $("[data-demo-caption]", demo);
      const readout = $("[data-range-readout]", demo);
      let frames = [];

      try {
        frames = JSON.parse(demo.dataset.frames || "[]");
      } catch (error) {
        console.warn("Invalid range demo data", error);
      }

      const update = () => {
        const frame = frames[Number(range.value)] || frames[0];
        if (!frame) return;
        swapImage(image, frame.src);
        if (caption) caption.innerHTML = frame.caption || "";
        if (readout) readout.textContent = frame.label || "";
      };

      range.addEventListener("input", update);
      update();
    });
  }

  function setupTorus() {
    const demo = $("#torus-sweep");
    if (!demo) return;

    const range = $('input[type="range"]', demo);
    const line = $(".sweep-line", demo);
    const singleLevel = $(".level-single", demo);
    const branchLevels = $$(".level-branch", demo);
    const reveal = $(".reeb-reveal", demo);
    const markers = $$(".reeb-level-marker", demo);
    const state = $("[data-torus-state]", demo);
    const readout = $("[data-range-readout]", demo);
    const splitHeight = 0.2;
    const mergeHeight = 0.68;

    const graphPosition = (t) => {
      if (t < splitHeight) {
        return { y: 300 - 80 * (t / splitHeight), offset: 0, components: 1 };
      }
      if (t < mergeHeight) {
        const u = (t - splitHeight) / (mergeHeight - splitHeight);
        return { y: 220 - 110 * u, offset: 92 * Math.sin(Math.PI * u), components: 2 };
      }
      return { y: 110 - 80 * ((t - mergeHeight) / (1 - mergeHeight)), offset: 0, components: 1 };
    };

    const updateTorusLevel = (t, y) => {
      const isSplit = t >= splitHeight && t < mergeHeight;
      singleLevel.style.display = isSplit ? "none" : "";
      branchLevels.forEach((ring) => {
        ring.style.display = isSplit ? "" : "none";
      });

      if (isSplit) {
        const u = (t - splitHeight) / (mergeHeight - splitHeight);
        const breadth = Math.sin(Math.PI * u);
        const offset = 100 + 65 * breadth;
        const rx = 72 + 25 * breadth;
        const ry = 24 + 12 * breadth;

        branchLevels.forEach((ring, index) => {
          ring.setAttribute("cx", String(410 + (index === 0 ? -offset : offset)));
          ring.setAttribute("cy", String(y));
          ring.setAttribute("rx", String(rx));
          ring.setAttribute("ry", String(ry));
        });
        return;
      }

      const distanceFromExtremum = t < splitHeight
        ? t / splitHeight
        : (1 - t) / (1 - mergeHeight);
      singleLevel.setAttribute("cy", String(y));
      singleLevel.setAttribute("rx", String(65 + 160 * distanceFromExtremum));
      singleLevel.setAttribute("ry", String(16 + 28 * distanceFromExtremum));
    };

    const update = () => {
      const t = Number(range.value) / 100;
      const y = 390 - t * 300;
      line.setAttribute("transform", `translate(0 ${y - 240})`);
      updateTorusLevel(t, y);

      const graph = graphPosition(t);
      const revealY = graph.y - 7;
      reveal.setAttribute("y", String(revealY));
      reveal.setAttribute("height", String(330 - revealY));

      markers[0].setAttribute("cx", String(165 - graph.offset));
      markers[0].setAttribute("cy", String(graph.y));
      markers[1].setAttribute("cx", String(165 + graph.offset));
      markers[1].setAttribute("cy", String(graph.y));
      markers[1].style.display = graph.components === 2 ? "" : "none";

      readout.textContent = `height ${Math.round(t * 100)}%`;

      if (t < 0.1) {
        state.innerHTML = "A level set is born: <strong>one component</strong>.";
      } else if (t < splitHeight) {
        state.innerHTML = "Below the hole, the fibre remains <strong>connected</strong>.";
      } else if (t < mergeHeight) {
        state.innerHTML = "Across the hole, the fibre <strong>splits in two</strong>. This is the loop.";
      } else if (t < 0.9) {
        state.innerHTML = "Above the hole, the two components <strong>merge again</strong>.";
      } else {
        state.innerHTML = "The last component dies. The quotient has recorded <strong>one cycle</strong>.";
      }
    };

    range.addEventListener("input", update);
    update();
  }

  function setupKeyboardShortcuts() {
    document.addEventListener("keydown", (event) => {
      const slide = $(".reveal .slides section.present");
      if (!slide || !["ArrowUp", "ArrowDown"].includes(event.key)) return;

      const range = $('input[type="range"]', slide);
      if (!range) return;
      event.preventDefault();
      const delta = event.key === "ArrowUp" ? 1 : -1;
      const step = Number(range.step || 1);
      const value = Math.min(Number(range.max), Math.max(Number(range.min), Number(range.value) + delta * step));
      range.value = String(value);
      range.dispatchEvent(new Event("input", { bubbles: true }));
    });
  }

  function init() {
    setupButtonDemos();
    setupRangeDemos();
    setupTorus();
    setupKeyboardShortcuts();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
