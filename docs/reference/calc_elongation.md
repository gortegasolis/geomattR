# Calculate Elongation Ratio from Minimum Bounding Rectangle

Calculates the elongation ratio of a polygon based on its minimum
bounding rectangle. The minimum bounding rectangle is computed from the
convex hull of the input polygon.

## Usage

``` r
calc_elongation(
  v,
  isHull = FALSE,
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

- output:

  Character string. Either `"value"` (default) to return the elongation
  ratio, or `"polygon"` to return the input geometry with
  `elongation_rectangle` added as an attribute.

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

If `output = "value"`, a numeric value representing the elongation ratio
of the input polygon from the current minimum-bounding-rectangle
approximation. If `output = "polygon"`, the input geometry with
`elongation_rectangle` added. When `by_feature = TRUE`, value output is
returned as a numeric vector (one value per feature). Higher values
indicate more elongated shapes.

## Details

In the current implementation, elongation is computed as the ratio of
the mean of the two largest side lengths to the mean of the two shortest
side lengths: \\E = \frac{\text{mean}(\text{long
sides})}{\text{mean}(\text{short sides})}\\

The minimum bounding rectangle is a planar (GEOS) construction. For
lon/lat input it is computed in a local Lambert azimuthal equal-area
projection centred on the feature, so that the *minimum* rectangle is
not distorted by the varying length of a degree of longitude; the
rectangle is then measured back in the input's CRS with the selected
`method`.

This approximation assumes the minimum bounding rectangle is unique,
which may not always be the case. Consider this with caution.

## References

Dražić, Slobodan, Nebojša Ralević, and Joviša Žunić. Shape Elongation
from Optimal Encasing Rectangles. *Computers & Mathematics with
Applications 60, no. 7 (2010): 2035–42*.
[doi:10.1016/j.camwa.2010.07.043](https://doi.org/10.1016/j.camwa.2010.07.043)
.

## Examples

``` r
library(terra)
#> terra 1.8.93
coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")
elongation <- calc_elongation(polygon)

# Using a pre-computed convex hull
hull_geom <- terra::hull(polygon, type = "convex")
elongation_hull <- calc_elongation(hull_geom, isHull = TRUE)
```
