# Calculate Geometric Attributes of Spatial Polygons

Calculates a comprehensive set of geometric attributes for spatial
polygon features. Supports both sequential and parallel execution
through an optional cluster argument.

## Usage

``` r
calculate_geometric_attributes(
  v,
  metrics = "all",
  cl = NULL,
  method = "geo",
  by_feature = TRUE
)
```

## Arguments

- v:

  A SpatVector object representing one or more polygons.

- metrics:

  Character string or vector specifying which metrics to calculate.
  Options are:

  - `"all"` (default): Calculate all available metrics

  - A single metric name as a string: Calculate only that metric

  - A character vector of metric names: Calculate specified metrics

  Available metric names: "area", "perimeter", "compactness", "reock",
  "elongation_rectangle", "num_holes", "hole_area", "hole_area_pct",
  "num_polygons", "ew_length", "ns_length", "maxlength", "bearing",
  "northerness", "fractaldimension", "sinuosity", "shape_index",
  "circularity_ratio", "decimallongitude", "decimallatitude"

- cl:

  A cluster object created by
  [`makeCluster`](https://rdrr.io/r/parallel/makeCluster.html), or
  `NULL` (default). When `NULL` features are processed sequentially.
  Passing a cluster enables parallel processing across the cluster
  workers.

- method:

  Character string passed to
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
  for distance-based metrics. One of `"geo"` (default, recommended),
  `"haversine"`, or `"cosine"`. All three are lon/lat great-circle
  methods; on a projected CRS, `method` is ignored and distances are
  Cartesian.

- by_feature:

  Logical. If `TRUE` (default), compute metrics for each feature
  independently. If `FALSE`, non-spatial columns are dropped, features
  are dissolved into a single geometry, and one set of metrics is
  returned.

## Value

The input SpatVector with additional columns containing the requested
geometric attributes:

- `area`: Total area in square meters. Wrapper around
  [`terra::expanse()`](https://rspatial.github.io/terra/reference/expanse.html).

- `perimeter`: Total perimeter length in meters. Wrapper around
  [`terra::perim()`](https://rspatial.github.io/terra/reference/perim.html).

- `compactness`: Polsby-Popper compactness.

- `reock`: Reock compactness.

- `elongation_rectangle`: Elongation index from the minimum bounding
  rectangle.

- `num_holes`: Number of holes (interior rings) in the polygon.

- `hole_area`: Total area of holes in square meters.

- `hole_area_pct`: Percentage of total area occupied by holes.

- `num_polygons`: Number of separate polygon parts (multi-part count).

- `ew_length`: East-west extent in meters.

- `ns_length`: North-south extent in meters.

- `maxlength`: Maximum Feret distance across the convex hull.

- `bearing`: Axial orientation of the maximum length line: geographic
  bearing from the southernmost to the northernmost point in decimal
  degrees, within \[-90, 90\] (0 = north-south, -90/90 = east-west).

- `northerness`: Cosine of bearing, within \[0, 1\] (1 = north-south
  axis, 0 = east-west axis).

- `fractaldimension`: Boundary complexity index (FRAGSTATS convention).

- `sinuosity`: Perimeter-to-maximum-length ratio.

- `shape_index`: Dimensionless irregularity index.

- `circularity_ratio`: Circularity index based on area and maximum hull
  distance.

- `decimallongitude`: Centroid longitude in decimal degrees.

- `decimallatitude`: Centroid latitude in decimal degrees.

## Details

Each polygon is processed independently via the internal function
`.calculate_geometric_attributes_single`, which handle a single feature
at a time, but it is optimized to ensure that intermediate objects
required for multiple metrics (convex hull, minimum circle, etc.) are
computed only once per feature.

**Sequential vs. Parallel:**

- When `cl = NULL` (default), features are processed sequentially with
  [`lapply`](https://rdrr.io/r/base/lapply.html).

- When `cl` is a valid cluster, features are distributed across workers
  via [`parLapply`](https://rdrr.io/r/parallel/clusterApply.html). The
  function handles library loading and function export to the cluster
  automatically.

**Geodesic Measurements:** The function supports the methods `"geo"`
(default), `"haversine"` and `"cosine"` (less precise but faster
great-circle approximations). All three are lon/lat great-circle methods
in
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html);
on a projected CRS `method` is ignored and distances are Cartesian.
Inputs are internally projected to EPSG:4326 when a metric requires
geographic coordinates and restored to the original CRS on return when
applicable.

**Scope of the `method` parameter:** The `method` argument is passed to
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
for distance-based metrics (extent, maxlength, and elongation). Area
([`terra::expanse()`](https://rspatial.github.io/terra/reference/expanse.html))
and perimeter
([`terra::perim()`](https://rspatial.github.io/terra/reference/perim.html))
use terra's built-in CRS-dependent calculations: geodesic for geographic
(lon/lat) CRS, Cartesian for projected CRS. When `method = "geo"` or
`"haversine"` and the input has a projected CRS, the geometry is
temporarily reprojected to EPSG:4326 where required by downstream
metrics.

**Size metrics:**

- Area: geodesic by default; handled according to the selected method.

- Perimeter: geodesic by default; handled according to the selected
  method.

- East-west extent: \\\bar{D}\_{EW} = \frac{d(NW, NE) + d(SW, SE)}{2}\\.

- North-south extent: \\\bar{D}\_{NS} = \frac{d(SW, NW) + d(SE,
  NE)}{2}\\.

- Maximum length (Feret diameter): \\L\_{\max} = \max\_{p_i, p_j} d(p_i,
  p_j)\\.

**Shape metrics:**

- Compactness (Polsby-Popper): area normalized by perimeter, relative to
  a circle: \\C = \frac{4\pi A}{P^2}\\.

- Reock compactness: \\R = \frac{A}{A\_{MEC}}\\. The minimum enclosing
  circle is computed in a local Lambert azimuthal equal-area projection
  centred on the feature (GEOS hulls are planar), then measured back in
  the input's CRS.

- Shape index (perimeter relative to a circle of equal area): \\SI =
  \frac{P}{2\sqrt{\pi A}}\\.

- Circularity ratio: \\CR = \frac{4A}{\pi L\_{\max}^2}\\.

- Fractal dimension (FRAGSTATS convention; approaches 1 for simple,
  square-like shapes and 2 for highly convoluted boundaries): \\D =
  \frac{2 \ln(0.25 P)}{\ln(A)}\\.

- Sinuosity: \\S = \frac{P}{L\_{\max}}\\.

**Orientation metrics:**

- Bearing: orientation of the longest axis; computed from geographic
  coordinates when needed.

- Northerness: \\N = \cos(\text{bearing} \times \frac{\pi}{180})\\.

- Elongation: ratio of major to minor axis of the minimum bounding
  rectangle. Elongation is calculated as the ratio of the mean of the
  two largest side lengths to the mean of the two shortest side lengths:
  \\E = \frac{\text{mean}(\text{long sides})}{\text{mean}(\text{short
  sides})}\\.

**Hole and part metrics:**

- Hole area percentage, relative to the gross area (including holes):
  \\HA\\ = \frac{A\_{\text{holes}}}{A + A\_{\text{holes}}} \times 100\\.

- `num_holes`, `hole_area`, and `num_polygons` are direct counts/areas
  derived from polygon topology.

## References

Reock, E. C. (1961). Measuring compactness as a requirement of
legislative apportionment. *Midwest Journal of Political Science*, 5(1),
70-74. [doi:10.2307/2109043](https://doi.org/10.2307/2109043)

Dražić, Slobodan, Nebojša Ralević, and Joviša Žunić. Shape Elongation
from Optimal Encasing Rectangles. *Computers & Mathematics with
Applications 60, no. 7 (2010): 2035–42*.
[doi:10.1016/j.camwa.2010.07.043](https://doi.org/10.1016/j.camwa.2010.07.043)
.

McGarigal, K., and B. J. Marks. FRAGSTATS: Spatial Pattern Analysis
Program for Quantifying Landscape Structure. *Gen. Tech. Rep.
PNW-GTR-351*. Portland, OR: USDA Forest Service, Pacific Northwest
Research Station (1995).
[doi:10.2737/PNW-GTR-351](https://doi.org/10.2737/PNW-GTR-351)

## Examples

``` r
library(terra)

# Create a sample 1-degree square polygon near the equator
coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
polygons <- vect(coords, type = "polygon", crs = "EPSG:4326")

# Sequential processing (default)
result <- calculate_geometric_attributes(polygons)

# Calculate specific metrics only
result <- calculate_geometric_attributes(polygons,
  metrics = c("area", "perimeter", "compactness")
)

if (FALSE) { # \dontrun{
# Parallel processing with an explicit cluster (use small number of cores for checks)
cl <- parallel::makeCluster(2)
result <- calculate_geometric_attributes(polygons, cl = cl)
parallel::stopCluster(cl)
} # }
```
