# Filtrage

## Vue d'ensemble

rs-grid prend en charge deux mécanismes de filtrage par colonne,
indépendants et combinés en ET, tous deux accessibles dans le même
popup :

- **Filtrage par condition** — chaque filtre actif est un opérateur
  (`FilterOp`) associé à une valeur de comparaison (`FilterCondition`),
  évalué sur chaque cellule de la colonne.
- **Liste à cases à cocher** — un ensemble de valeurs autorisées par
  colonne (le « Set Filter » d'AG Grid) : seules les lignes dont la
  valeur de cellule appartient à cet ensemble passent.

L'en-tête de colonne lui-même reste sobre (nom + icône de menu « ⋮ »,
façon AG Grid) — l'interface de filtrage vit dans la [ligne de filtre
flottante](#ligne-de-filtre-flottante) optionnelle en dessous : un champ
de saisie « contient » rapide par colonne, plus une petite icône en
forme d'entonnoir qui ouvre un popup complet pour les deux mécanismes
ci-dessus, sans code UI personnalisé. Chacun peut aussi être défini par
programmation via `GridCommand::SetColumnFilter` /
`SetColumnValueFilter`.

## Popup de filtre (interface interactive)

Activez la [ligne de filtre flottante](#ligne-de-filtre-flottante) et
cliquez sur la petite icône en forme d'entonnoir d'une cellule pour
ouvrir un popup pour cette colonne. Une ligne « Text Filter » repliée
se déplie (clic, ou `Entrée`/`Espace`) en un panneau flottant à côté du
popup, avec un `<select>` d'opérateur (Contient, Égal, Supérieur à,
...) et un `<input>` de valeur ; la liste à cases à cocher (voir
ci-dessous) et les boutons Appliquer / Effacer restent affichés
directement dans le popup principal.

- L'icône entonnoir de la ligne de filtre change de couleur quand la
  colonne a une condition active **ou** un filtre par valeurs — elle
  sert donc aussi d'indicateur visuel des colonnes filtrées.
- Le popup se ferme sur Appliquer, Effacer, un clic à l'extérieur, ou
  Échap. Appliquer déclenche `GridCommand::SetColumnFilter` (condition)
  et, si la liste était affichée,
  `SetColumnValueFilter`/`ClearColumnValueFilter` (liste). Effacer
  supprime toujours les deux, quel que soit l'état de la liste.
- Clic droit sur un en-tête de colonne (ou son icône de menu « ⋮ ») —
  **Effacer le filtre** n'apparaît que si cette colonne a une condition
  ou un filtre par valeurs actif, en raccourci à côté du bouton Effacer
  du popup.

### Liste à cases à cocher (Set Filter)

Sous le formulaire de condition, le popup affiche un champ de recherche,
une case « (Tout sélectionner) », et une case à cocher par valeur
distincte de la colonne — chaque valeur démarre cochée (aucune
restriction) sauf si un filtre par valeurs est déjà actif dessus.

- La liste est construite via `GridModel::unique_values(col_key, cap)`,
  qui parcourt jusqu'à `MAX_CLIENT_SORT_ROWS` lignes et renvoie
  `UniqueValues::Values` (triées) ou `UniqueValues::TooMany { cap }` dès
  que le nombre de valeurs distinctes dépasse `cap`. Le popup intégré ne
  transmet aucune limite pratique, donc chaque valeur distincte est
  listée quelle que soit la cardinalité de la colonne — `TooMany` n'a
  d'importance que si vous construisez votre propre interface de liste
  avec un `cap` plus restreint.
- Le champ de recherche masque seulement les lignes non correspondantes
  (`display: none`) ; il ne perd jamais leur état coché.
- « (Tout sélectionner) » est un vrai contrôle tri-état (coché / décoché
  / indéterminé), agissant sur les valeurs actuellement _visibles_
  (filtrées par la recherche) lorsqu'il est basculé.
- Recocher toutes les valeurs supprime entièrement le filtre par valeurs
  de la colonne (plutôt que de stocker un ensemble « toutes valeurs
  autorisées » sans effet), afin que la couleur active/inactive de
  l'icône entonnoir reste fidèle à l'état réel.

## Ligne de filtre flottante

Une seconde ligne optionnelle, directement sous les en-têtes de
colonnes — la « floating filter row » d'AG Grid — pour un filtre rapide
« contient » par colonne, et seul point d'accès au [popup de
filtre](#popup-de-filtre-interface-interactive) ci-dessus. Désactivée
par défaut ; activez-la avec `GridCommand::SetShowFilterRow(true)` (ou
`GridCanvas::set_show_filter_row(true)`).

- Chaque cellule affiche la valeur de filtre actuelle de la colonne, ou
  rien si aucune n'est définie — lue au mieux, quel que soit
  l'opérateur utilisé pour la définir (taper dans la ligne applique
  toujours `FilterOp::Contains`, la même simplification qu'AG Grid
  applique elle-même pour les conditions qu'elle ne peut pas
  représenter en ligne).
- Cliquez sur une cellule pour ouvrir un champ de saisie ; `Entrée` ou un
  clic ailleurs applique le filtre, `Échap` annule sans appliquer.
- Chaque cellule a aussi sa propre petite icône en forme d'entonnoir,
  qui ouvre le popup complet, pour tout ce qui dépasse le simple
  « contient ».
- `GridCommand::SetFilterRowHeight(f64)` définit la hauteur de la ligne
  (ignoré si `<= 0.0`) ; la valeur par défaut est 36 pixels logiques.

## Opérateurs (`FilterOp`)

| Opérateur                                                             | Signification                                                                                                                                                |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Contains` / `NotContains`                                            | Correspondance de sous-chaîne insensible à la casse                                                                                                          |
| `StartsWith` / `EndsWith`                                             | Correspondance de préfixe/suffixe insensible à la casse                                                                                                      |
| `Equals` / `NotEquals`                                                | Comparaison numérique si le format de la colonne est numérique (`Number`/`Percent`/`Currency`/`ProgressBar`), sinon égalité de chaînes insensible à la casse |
| `Blank` / `NotBlank`                                                  | La valeur de la cellule est vide après suppression des espaces — ignore la `value` de la condition                                                           |
| `GreaterThan` / `GreaterThanOrEqual` / `LessThan` / `LessThanOrEqual` | Toujours numérique, quel que soit le format de la colonne — une cellule non numérique ne correspond jamais (jamais de panique)                               |

## Commandes (API programmatique)

### Définir une condition de filtre

```rust
use rs_grid_core::filter::{FilterCondition, FilterOp};

// Le cas courant — sucre syntaxique pour FilterOp::Contains.
state.apply(GridCommand::SetColumnFilter {
    col_key: "name".into(),
    condition: FilterCondition::contains("john"),
});

// N'importe quel opérateur.
state.apply(GridCommand::SetColumnFilter {
    col_key: "revenue".into(),
    condition: FilterCondition {
        op: FilterOp::GreaterThan,
        value: "100000".into(),
    },
});
```

Un opérateur nécessitant une valeur (toutes les variantes sauf
`Blank`/`NotBlank`) associé à une `value` vide supprime le filtre de cette
colonne — vérifiez avec `FilterCondition::is_empty()`.

### Définir un filtre par valeurs (liste à cocher)

```rust
use std::collections::HashSet;

state.apply(GridCommand::SetColumnValueFilter {
    col_key: "country".into(),
    values: HashSet::from(["France".to_string(), "Germany".to_string()]),
});

// Un ensemble vide est valide — il ne correspond à aucune ligne.
state.apply(GridCommand::SetColumnValueFilter {
    col_key: "country".into(),
    values: HashSet::new(),
});

// Supprimer la restriction (le filtre par condition de la colonne,
// s'il existe, n'est pas touché).
state.apply(GridCommand::ClearColumnValueFilter {
    col_key: "country".into(),
});
```

Les deux mécanismes de filtrage se combinent en ET : une ligne doit
satisfaire à la fois la condition (si présente) et la restriction par
valeurs (si présente) pour être visible.

### Valeurs distinctes d'une colonne

```rust
use rs_grid_core::filter::UniqueValues;

match state.model.unique_values("country", 200) {
    UniqueValues::Values(values) => { /* une case à cocher par valeur */ }
    UniqueValues::TooMany { cap } => { /* afficher un message à la place */ }
}
```

### Effacer tous les filtres

```rust
state.apply(GridCommand::ClearAllFilters);
```

Efface à la fois `filters` et `value_filters` pour toutes les colonnes.

`GridCanvas` expose aussi `set_filter(col_key, text)` (sucre syntaxique
pour `FilterOp::Contains`), `set_filter_condition(col_key, condition)`
(tout opérateur), et `clear_filters()`. Le popup relit l'état du filtre à
chaque ouverture, donc appeler ces méthodes par programmation puis ouvrir
le popup affiche toujours la condition à jour.

## Fonctionnement

### Mode côté client (par défaut)

Lorsqu'un filtre est actif, `apply_filter()` parcourt toutes les lignes et
construit `filtered_indices: Vec<u64>` — la liste des indices de lignes
physiques qui satisfont toutes les conditions actives et restrictions par
valeurs, stockée dans l'ordre de tri.

Chaque condition et restriction par valeurs actives se combinent en ET :
une ligne doit toutes les satisfaire, sur toutes les colonnes, pour être
visible.

`model.display_row_count()` renvoie le nombre de lignes filtrées (ou le
total lorsqu'aucun filtre n'est actif) — en interne, il vérifie
`model.is_filter_applied()` plutôt que `filtered_indices.is_empty()`,
car un filtre actif qui ne correspond véritablement à aucune ligne laisse
aussi `filtered_indices` vide ; les deux cas ne doivent pas être confondus.

:::warning
Le filtrage côté client est conçu pour des jeux de données allant jusqu'à \~1 million de lignes.
Pour des volumes plus importants, utilisez le mode côté serveur.
:::

### Mode côté serveur

Lorsque `model.mode = DataSourceMode::ServerSide`, `apply_filter()` est un
no-op. L'état du filtre est néanmoins stocké dans `model.filters`/
`model.value_filters` pour que votre application puisse le lire et le
transmettre au serveur.

## État des filtres

Les filtres actifs sont stockés dans
`model.filters: HashMap<String, FilterCondition>` et
`model.value_filters: HashMap<String, HashSet<String>>`, associant
chacun les clés de colonnes à leur état respectif. Vous pouvez lire ces
structures pour construire des requêtes serveur :

```rust
for (col_key, condition) in &state.model.filters {
    println!("Filtre sur {}: {:?} {}", col_key, condition.op, condition.value);
}
for (col_key, values) in &state.model.value_filters {
    println!("Filtre par valeurs sur {}: {:?}", col_key, values);
}
```

## Interaction avec le tri

Le filtrage respecte l'ordre de tri actif. Lorsque les deux sont actifs,
`filtered_indices` contient les indices de lignes physiques dans l'ordre trié.
