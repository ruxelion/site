Open Source · Rust · WebAssembly

# The data grid engine
built for performance

A data grid that never slows down. Scroll through millions of rows as smoothly as the first hundred — editing, sorting, and selecting included.

[Get started](/getting-started)[View on GitHub](https://github.com/ruxelion/rs-grid)

∞rows, zero lag

<53 µsper frame at 60fps

45.9 nshit-test (1 quadrillion rows)

Pure Rustcompiled to WASM

MITopen source

Live Demo

## See it in action

This is a real rs-grid instance running in your browser via WebAssembly. Scroll, select cells, resize columns — all at 60 fps.

1K rows100K rows1M rows

[### See it integrated with your framework

The same grid, mounted via each official framework wrapper. Each demo is a real CSR app running in your browser.

![](/images/frameworks/leptos.png)Leptos · CSR

![](/images/frameworks/dioxus.png)Dioxus · CSR

![](/images/frameworks/yew.png)Yew · CSROpen the framework demos](/demos)

Why rs-grid

## Built for the hard constraints

Most grid libraries struggle past 100k rows. rs-grid is designed from the ground up for virtualization, performance, and long-term maintainability.

### Millions of rows

Only visible cells are rendered. Memory stays constant whether you have 1K or 10M rows.

### Inline editing

Double-click to edit cells. Text inputs, dropdowns with icons. Full undo/redo history.

### Sort & filter

Per-column sorting with visual indicators. Text filtering, combinable across columns.

### Clipboard

Cut, copy, paste with Ctrl+C/X/V. TSV format, compatible with Excel and Google Sheets.

### Column management

Resize by drag, auto-fit on double-click, reorder by drag-and-drop, pin columns to the left.

### Rich cell formats

Number, currency, percentage, boolean, images, image+text combos. Custom formatters for full control.

### Keyboard navigation

Arrow keys, Shift+Arrow for selection, Enter to edit, Escape to cancel. All spreadsheet shortcuts built in.

### Full-text search

Ctrl+F to search across all cells. Matches highlighted in-place with next/previous navigation.

### CSS theming

Style everything via CSS custom properties. Light, dark, or build your own. Hot-swap at runtime.

### Server-side data

Async pagination with LRU cache. Sort and filter can be delegated to your backend.

### Context menu

Right-click menu with cut, copy, paste, pin columns. Fully customizable items and actions.

### Pure Rust & WebAssembly

Zero JavaScript runtime. Core logic compiled to WASM. Works with any framework or vanilla JS.

Architecture

## One direction, no surprises

A strict unidirectional dependency graph keeps each crate focused and independently testable.

GridState

model · viewport · selection

→

SceneBuilder

rs-grid-scene

→

SceneFrame

primitives

→

CanvasRenderer

rs-grid-render-canvas

→

<canvas>

browser

`rs-grid-core`

Headless logic: model, viewport, selection, hit-testing. No WASM dependency.

`rs-grid-scene`

Converts GridState to renderer-agnostic ScenePrimitive list.

`rs-grid-render-canvas`

Canvas2D backend via wasm-bindgen. Draws primitives to the DOM.

`rs-grid-web`

Browser glue: events, DPR, rAF loop, CSS theme parsing.

`rs-grid-leptos`

Leptos CSR component wrapping the full pipeline.

## Start building today

Open source, MIT license. Contributions welcome.

[Read the docs](/getting-started)[GitHub ↗](https://github.com/ruxelion/rs-grid)