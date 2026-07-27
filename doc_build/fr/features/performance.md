# Performance

Tous les chiffres de cette page proviennent de vrais benchmarks [Criterion](https://bheisler.github.io/criterion.rs/book/)
tournant sur `ubuntu-22.04` en CI, mis à jour automatiquement à chaque push sur `main`.
Le claim central : **le coût de rs-grid évolue avec ce qu'on affiche, pas avec ce qu'on stocke.**

## Pipeline de frame — O(cellules visibles)

Le coût complet par frame — `ScrollBy` → recalcul viewport → `SceneBuilder::build()` — mesuré
sur des datasets de tailles radicalement différentes. Le renderer ne voit que les \~275 cellules
visibles dans le viewport à un instant donné, indépendamment du nombre total de lignes.


Time per frame (µs)60fps budget: 16,600 µs

20 cols × 10k rows41.5 µs

50 cols × 1M rows52.1 µs

100 cols × 10M rows64.6 µs

1 000 cols × 1B rows65.9 µs

50 cols × 1 quadrillion54.0 µs

All configs render in 65–89 µs — less than 0.6% of the 16.6 ms frame budget at 60fps. Row count has zero impact on frame time.


## Hit-test — O(log n\_cols)

Chaque clic, survol ou drag commence par un hit-test : convertir une coordonnée viewport en
adresse `(ligne, col)`. La résolution des colonnes utilise des offsets précalculés et une
recherche binaire — O(log n\_cols). La résolution des lignes est O(1) grâce à la hauteur uniforme.
Le nombre total de lignes est sans effet.


Varying row count (1 000 cols fixed)

| Configuration | Hit-test time |
| --- | --- |
| 1 000 rows, 1 000 cols | 48.6 ns |
| 1 billion rows, 1 000 cols | 74.0 ns |
| 1 quadrillion rows, 1 000 cols | 45.9 ns |

Varying column count (O(log n) in action)

| Columns | Hit-test time |
| --- | --- |
| 10 cols | 18.8 ns |
| 100 cols | 23.9 ns |
| 1 000 cols | 34.5 ns |


L'augmentation de 1,7× de 10 à 1 000 colonnes (10 → 18 ns) reflète la recherche binaire sur
les offsets de colonnes. Passer de 1 000 lignes à 1 quadrillion de lignes ne coûte **rien**.

## Initialisation — O(n\_cols)

`GridState::new` précalcule les offsets de colonnes et les largeurs flex. Avec `FnDataSource`
(lignes virtuelles), le nombre de lignes est juste un `u64` — sans coût d'allocation.


Varying row count — FnDataSource (20 cols fixed)

| Rows | Init time |
| --- | --- |
| 1 000 | 3.0 µs |
| 100 000 | 3.2 µs |
| 1 000 000 | 3.2 µs |
| 100 000 000 | 3.1 µs |
| 1 000 000 000 | 3.2 µs |
| 1 000 000 000 000 000 | 3.1 µs |

Flat regardless of row count — O(n_cols), not O(n_rows).

Varying column count (1M rows fixed)

5 cols0.8 µs

20 cols3.2 µs

50 cols8.3 µs

100 cols17.0 µs

1 000 cols170.1 µs

Initialiser un grid avec **1 quadrillion de lignes virtuelles** prend les mêmes \~5 µs qu'un
grid de 1 000 lignes. Si toutes les données sont en mémoire (`VecDataSource`), l'initialisation
reste dominée par le nombre de colonnes, pas de lignes.

## Tri — 100 000 lignes

Le tri utilise un algorithme en deux phases : les colonnes numériques utilisent un radix sort
LSD à 8 passes (O(8n)) ; les colonnes texte tombent en fallback sur `sort_unstable_by`. Un
cache de clés évite de ré-extraire les valeurs lors d'un toggle de direction sur la même colonne.


100 000 rows — sort time (ms)

Numeric sort (cold)16.9 ms

Radix sort, first call — key extraction + sort

Numeric sort (cached)11.8 ms

Radix sort, direction toggle — keys reused from cache

String sort (cold)21.7 ms

Lexicographic comparison sort


Le tri côté client est limité à 1 000 000 lignes (`MAX_CLIENT_SORT_ROWS`). Au-delà, rs-grid
émet un `SortWarning` et délègue au backend.

## Mémoire par ligne

La datasource détermine le coût mémoire par ligne. Avec `FnDataSource`, les lignes n'allouent
rien — les données sont générées à la demande. Avec `VecDataSource`, chaque `RowRecord` alloue
une `HashMap`.


| Data source | Description | Memory / row |
| --- | --- | --- |
| FnDataSource | Virtual / server-side — data generated on demand | **0 bytes** |
| VecDataSource (empty rows) | In-memory, no cell values | 56 B |
| VecDataSource (10 cols, ~8 chars) | In-memory, realistic cell data | 1.1 KB |


Pour les grands datasets (> 100k lignes), préférez `FnDataSource` avec pagination côté serveur.
Voir [FnDataSource](/fr/data/fn-datasource.md) et [PageCache](/fr/data/page-cache.md).


Measured with Criterion (sample-size=10) on `ubuntu-22.04` · commit `226b085` · July 22, 2026. Updated automatically on every push to `main` via CI.

