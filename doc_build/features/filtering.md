# Filtering

## Overview

rs-grid supports two independent, AND-combined per-column filter
mechanisms, both surfaced in the same popup:

- **Condition filtering** — each active filter is an operator
  (`FilterOp`) plus a comparison value (`FilterCondition`), evaluated
  against every cell in that column.
- **Value checklist** — a set of allowed values per column (AG Grid's
  "Set Filter"): only rows whose cell value is in the set pass.

The column header itself stays plain (name + a "⋮" menu icon, AG-Grid
style) — filtering UI lives in the optional [floating filter
row](#floating-filter-row) below it: a quick "contains" input per
column, plus a small funnel icon that opens a full popup for both
mechanisms above without any custom UI work. Either can also be set
programmatically via `GridCommand::SetColumnFilter` /
`SetColumnValueFilter`.

## Filter popup (interactive UI)

Enable the [floating filter row](#floating-filter-row) and click a
cell's small funnel icon to open a popup for that column. A collapsed
"Text Filter" row expands (click, or `Enter`/`Space`) into a flyout
panel beside the popup with an operator `<select>` (Contains, Equals,
Greater than, ...) and a value `<input>`; the value checklist (see
below) and the Apply / Clear buttons stay inline in the main popup.

- The floating filter row's funnel icon changes color when the column
  has an active condition **or** value filter, so it doubles as an
  at-a-glance indicator of which columns are filtered.
- The popup closes on Apply, Clear, an outside click, or Escape. Apply
  dispatches `GridCommand::SetColumnFilter` (condition) and, if the
  checklist was shown, `SetColumnValueFilter`/`ClearColumnValueFilter`
  (checklist). Clear always clears both, regardless of checklist state.
- Right-click a column header (or use its "⋮" menu icon) — **Clear
  Filter** appears only when that column has an active condition or
  value filter, as a shortcut alongside the popup's own Clear button.

### Value checklist (Set Filter)

Below the condition form, the popup shows a search box, a
"(Select All)" checkbox, and one checkbox per distinct value in that
column — every value starts checked (no restriction) unless a value
filter is already active for it.

- The list is built from `GridModel::unique_values(col_key, cap)`,
  which scans up to `MAX_CLIENT_SORT_ROWS` rows and returns
  `UniqueValues::Values` (sorted) or `UniqueValues::TooMany { cap }`
  once the distinct count exceeds `cap`. The built-in popup passes no
  practical cap, so every distinct value is listed regardless of column
  cardinality — `TooMany` only matters if you build a custom checklist
  UI around a smaller `cap` of your own.
- The search box only hides non-matching rows (`display: none`); it
  never discards their checked state.
- "(Select All)" is a real tri-state control (checked / unchecked /
  indeterminate), acting on the currently _visible_ (search-filtered)
  values when toggled.
- Rechecking every value clears the column's value filter entirely
  (rather than storing a no-op "all values allowed" set), so the
  funnel icon's active/inactive color stays accurate.

## Floating filter row

An optional second row directly under the column headers — AG Grid's
floating filter row — for a quick "contains" filter per column, and the
only click path to the [filter popup](#filter-popup-interactive-ui)
above. Off by default; enable it with `GridCommand::SetShowFilterRow(true)`
(or `GridCanvas::set_show_filter_row(true)`).

- Each cell shows the column's current filter value, or nothing when
  none is set — read best-effort regardless of which operator was used
  to set it (typing into the row always sets `FilterOp::Contains`, the
  same simplification AG Grid's own floating filter makes for
  conditions it can't represent inline).
- Click a cell to open an input and type; `Enter` or clicking elsewhere
  applies the filter, `Escape` cancels without applying.
- Each cell also has its own small funnel icon that opens the full
  popup, for anything more advanced than "contains."
- `GridCommand::SetFilterRowHeight(f64)` sets the row's height (ignored
  if `<= 0.0`); the default is 36 logical pixels.

## Operators (`FilterOp`)

| Operator                                                              | Meaning                                                                                                                                            |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Contains` / `NotContains`                                            | Case-insensitive substring match                                                                                                                   |
| `StartsWith` / `EndsWith`                                             | Case-insensitive prefix/suffix match                                                                                                               |
| `Equals` / `NotEquals`                                                | Numeric compare when the column's format is numeric-like (`Number`/`Percent`/`Currency`/`ProgressBar`), otherwise case-insensitive string equality |
| `Blank` / `NotBlank`                                                  | Cell value is empty after trimming whitespace — ignores the condition's `value`                                                                    |
| `GreaterThan` / `GreaterThanOrEqual` / `LessThan` / `LessThanOrEqual` | Always numeric, regardless of column format — a non-numeric cell never matches (never panics)                                                      |

## Commands (programmatic API)

### Set a filter condition

```rust
use rs_grid_core::filter::{FilterCondition, FilterOp};

// The common case — sugar for FilterOp::Contains.
state.apply(GridCommand::SetColumnFilter {
    col_key: "name".into(),
    condition: FilterCondition::contains("john"),
});

// Any operator.
state.apply(GridCommand::SetColumnFilter {
    col_key: "revenue".into(),
    condition: FilterCondition {
        op: FilterOp::GreaterThan,
        value: "100000".into(),
    },
});
```

An operator that needs a value (every variant except `Blank`/`NotBlank`)
paired with an empty `value` clears the filter for that column — check
with `FilterCondition::is_empty()`.

### Set a value-set (checklist) filter

```rust
use std::collections::HashSet;

state.apply(GridCommand::SetColumnValueFilter {
    col_key: "country".into(),
    values: HashSet::from(["France".to_string(), "Germany".to_string()]),
});

// An empty set is valid — it matches no rows.
state.apply(GridCommand::SetColumnValueFilter {
    col_key: "country".into(),
    values: HashSet::new(),
});

// Remove the restriction (the column's condition filter, if any, is
// untouched).
state.apply(GridCommand::ClearColumnValueFilter {
    col_key: "country".into(),
});
```

The two filter mechanisms AND-combine: a row must pass both the
condition (if any) and the value-set restriction (if any) to be visible.

### Distinct values for a column

```rust
use rs_grid_core::filter::UniqueValues;

match state.model.unique_values("country", 200) {
    UniqueValues::Values(values) => { /* one checkbox per value */ }
    UniqueValues::TooMany { cap } => { /* show a message instead */ }
}
```

### Clear all filters

```rust
state.apply(GridCommand::ClearAllFilters);
```

Clears both `filters` and `value_filters` for every column.

`GridCanvas` also exposes `set_filter(col_key, text)` (sugar for
`FilterOp::Contains`), `set_filter_condition(col_key, condition)` (any
operator), and `clear_filters()`. The popup reads current filter state
fresh each time it opens, so calling these programmatically and then
opening the popup always shows the up-to-date condition.

## How it works

### Client-side mode (default)

When a filter is active, `apply_filter()` scans all rows and builds
`filtered_indices: Vec<u64>` — the list of physical row indices that pass
every active condition and value-set restriction, stored in sort order.

Every active condition and value-set restriction is AND-combined: a row
must match all of them, across all columns, to be visible.

`model.display_row_count()` returns the number of filtered rows (or the
total count when no filter is active) — internally it checks
`model.is_filter_applied()` rather than `filtered_indices.is_empty()`,
since an active filter that genuinely matches zero rows also leaves
`filtered_indices` empty; the two cases must not be conflated.

:::warning
Client-side filtering is designed for datasets up to \~1 million rows. For
larger datasets, use server-side mode.
:::

### Server-side mode

When `model.mode = DataSourceMode::ServerSide`, `apply_filter()` is a
no-op. The filter state is still stored in `model.filters`/
`model.value_filters` for your application to read and forward to the
server.

## Filter state

Active filters are stored in
`model.filters: HashMap<String, FilterCondition>` and
`model.value_filters: HashMap<String, HashSet<String>>`, both mapping
column keys to their respective state. You can read these to build
server queries:

```rust
for (col_key, condition) in &state.model.filters {
    println!("Condition on {}: {:?} {}", col_key, condition.op, condition.value);
}
for (col_key, values) in &state.model.value_filters {
    println!("Value filter on {}: {:?}", col_key, values);
}
```

## Interaction with sorting

Filtering respects the active sort order. When both are active,
`filtered_indices` contains physical row indices in sorted order.
