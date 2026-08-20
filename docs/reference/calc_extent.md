# Calculate Polygon Extent

Calculates east-west and/or north-south extent of a polygon based on its
geographic bounding box corners.

## Usage

``` r
calc_extent(
  v,
  isHull = FALSE,
  direction = c("ew", "ns"),
  output = "value",
  method = "geo",
  by_feature = FALSE
)
```

## Arguments

- v:

  A SpatVector object representing a polygon, or a pre-computed convex
  hull if `isHull = TRUE`.

- isHull:

  Logical. If `TRUE`, `v` is treated as a pre-computed convex hull. If
  `FALSE` (default), the convex hull is computed internally.

- direction:

  Character vector indicating which extent(s) to return when
  `output = "value"` or `output = "polygon"`. Valid values are `"ew"`
  and `"ns"`. Default is both.

- output:

  Character string. Either `"value"` (default) to return extent values,
  or `"polygon"` to return the input geometry with the requested extent
  columns added.

- method:

  Character string passed to
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html).
  Defaults to `"geo"` (recommended). Other supported options are
  `"haversine"` and `"cosine"`. All three are lon/lat great-circle
  methods; on a projected CRS, `method` is ignored and distances are
  Cartesian. See
  [`distance`](https://rspatial.github.io/terra/reference/distance.html)
  for more information.

- by_feature:

  Logical. If `FALSE` (default), compute a single response from the
  convex hull of the whole input set. If `TRUE`, compute one response
  per polygon feature.

## Value

If `output = "value"` and one direction is requested, returns a numeric
scalar. If both directions are requested, returns a named numeric vector
with `ew_length` and `ns_length`. If `output = "polygon"`, returns the
input geometry with the requested extent columns added. When
`by_feature = TRUE`, value output is returned per feature (numeric
vector for one direction, data.frame for both directions).

## Details

Extent is computed from the bounding box of the polygon's convex hull.
The Southwest (SW), Southeast (SE), Northwest (NW), and Northeast (NE)
corners of this box are evaluated using
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
with the selected `method`.

The metric values are calculated as:

- **East-West Extent**: The average length of the top and bottom
  bounding box edges: \$\$\text{EW} = \frac{d(SW, SE) + d(NW,
  NE)}{2}\$\$

- **North-South Extent**: The average length of the left and right
  bounding box edges: \$\$\text{NS} = \frac{d(SW, NW) + d(SE,
  NE)}{2}\$\$

When `method` is `"geo"` or `"haversine"`, the hull is projected to
EPSG:4326 when needed before distance calculations.

For `output = "value"`:

- `direction = "ew"`: returns east-west extent (numeric scalar)

- `direction = "ns"`: returns north-south extent (numeric scalar)

- `direction = c("ew", "ns")` (any order): returns both values as a
  named numeric vector

For `output = "polygon"`, only the requested extent columns are added as
attributes.

For interpretation and relation to other shape metrics, see
[`calculate_geometric_attributes`](https://gortegasolis.github.io/geomattR/reference/calculate_geometric_attributes.md).

## Examples

``` r
library(terra)
coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")

# Get one extent value
ew_extent <- calc_extent(polygon, direction = "ew")

# Get both extent values
both_extents <- calc_extent(polygon, direction = c("ns", "ew"))

# Return polygon with only requested extent columns
polygon_with_ew <- calc_extent(polygon, direction = "ew", output = "polygon")

# Return polygon with both extent columns
polygon_with_extents <- calc_extent(polygon, output = "polygon")

# Use a custom distance method supported by terra::distance()
extents_planar <- calc_extent(polygon, direction = c("ew", "ns"), method = "cosine")
```
