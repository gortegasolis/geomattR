# Find largest distance between a pair of opposite vertices

Identifies the pair of most distant points on a polygon's convex hull
and calculates their distance (using the selected `method`) and the
bearing from the southernmost to the northernmost point.

## Usage

``` r
get_distant_points(
  v,
  isHull = FALSE,
  distance = TRUE,
  bearing = TRUE,
  output = "points",
  by_feature = FALSE,
  method = "geo"
)
```

## Arguments

- v:

  A SpatVector object representing a polygon, or a pre-computed convex
  hull if `isHull = TRUE`.

- isHull:

  Logical. If `TRUE`, `v` is treated as a pre-computed convex hull. If
  `FALSE` (default), the convex hull is computed internally.

- distance:

  Logical indicating whether to return the maximum distance (default
  `TRUE`).

- bearing:

  Logical indicating whether to return the bearing (default `TRUE`).

- output:

  Character string. `"points"` (default) returns point geometry outputs.
  `"value"` returns numeric metric values only, and `"polygon"` returns
  the input geometry with requested metric columns added.

- by_feature:

  Logical. If `FALSE` (default), compute a single response from the
  convex hull of the whole input set. If `TRUE`, compute one response
  per polygon feature.

- method:

  Character string passed to
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html).
  Defaults to `"geo"` (recommended). Other supported options are
  `"haversine"` and `"cosine"`. All three are lon/lat great-circle
  methods; on a projected CRS, `method` is ignored and distances are
  Cartesian. Bearing is computed from geographic coordinates when
  needed.

## Value

For `output = "points"`, a list containing:

- south_point:

  SpatVector of the southernmost point

- north_point:

  SpatVector of the northernmost point

- distance:

  Maximum distance in meters (if `distance = TRUE`)

- bearing:

  Axial orientation: geographic bearing from the southernmost to the
  northernmost point, in degrees within \[-90, 90\] (if
  `bearing = TRUE`). Because the pair is always ordered south to north,
  this describes the orientation of the longest axis, not a travel
  direction: -90/90 is east-west, 0 is north-south.

For `output = "value"`, returns a numeric scalar when one metric is
requested, or a named numeric vector when both are requested. For
`output = "polygon"`, returns the input geometry with the requested
metric columns added. When `by_feature = TRUE`, returns per-feature
outputs (list, numeric vector/data.frame, or polygon with columns,
depending on `output`).

## Details

Distances between **all** convex-hull vertex pairs are evaluated with
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
using the selected `method`, so the returned pair is the true geodesic
maximum (hulls are small, so the exhaustive search is cheap). An earlier
rotating-calipers implementation searched antipodal pairs in planar
coordinate space, which could miss the geodesic maximum on lon/lat data.

**Tie-breaking & Point Ordering:** If multiple antipodal pairs share the
maximum distance, ties are broken by selecting the pair containing the
southernmost (and then westernmost) coordinate. The points are ordered
in the output such that:

- `south_point` (point 1): the southernmost (and westernmost, in case of
  a tie) point of the pair.

- `north_point` (point 2): the northernmost (and easternmost) point of
  the pair.

The geographic bearing is calculated from `south_point` to `north_point`
using
[`geosphere::bearing()`](https://rdrr.io/pkg/geosphere/man/bearing.html).
When needed, the geometry is internally transformed to geographic
coordinates for bearing calculation.

## Examples

``` r
library(terra)
coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")
distant_pts <- get_distant_points(polygon)

# Using a pre-computed convex hull
hull_geom <- terra::hull(polygon, type = "convex")
distant_pts_hull <- get_distant_points(hull_geom, isHull = TRUE)
```
