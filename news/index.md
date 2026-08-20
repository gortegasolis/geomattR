# Changelog

## geomattR 0.3.0

Accuracy improvements for geodesic workflows. **Values of `reock`,
`elongation_rectangle` and `maxlength` may change** for lon/lat input,
especially at high latitudes:

- The minimum enclosing circle (`reock`) and minimum bounding rectangle
  (`elongation_rectangle`) are now computed in a local Lambert azimuthal
  equal-area projection centred on each feature, instead of in raw
  lon/lat degrees. GEOS hull constructions are planar, so minimizing in
  degree space distorted the “minimum” geometry wherever a degree of
  longitude is shorter than a degree of latitude. The hull is measured
  back in the input’s CRS.
- `maxlength` (and the `distance`/`bearing` outputs of
  [`get_distant_points()`](https://gortegasolis.github.io/geomattR/reference/get_distant_points.md))
  are now found by evaluating **all** convex-hull vertex pairs
  geodesically in a single vectorised
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
  call. The previous rotating-calipers candidate search operated in
  planar coordinate space and could miss the true geodesic maximum. The
  internal rotating-calipers helper was removed.

Performance and packaging:

- [`calculate_geometric_attributes()`](https://gortegasolis.github.io/geomattR/reference/calculate_geometric_attributes.md)
  gains a vectorised fast path when only `area`, `perimeter`,
  `decimallongitude` and/or `decimallatitude` are requested: terra’s
  multi-feature methods are called once instead of looping per feature.
- The `by_feature` branches of
  [`calc_extent()`](https://gortegasolis.github.io/geomattR/reference/calc_extent.md),
  [`calc_elongation()`](https://gortegasolis.github.io/geomattR/reference/calc_elongation.md)
  and
  [`get_distant_points()`](https://gortegasolis.github.io/geomattR/reference/get_distant_points.md)
  no longer compute (and discard) the convex hull of the entire input
  set.
- `NAMESPACE` now uses targeted `importFrom()` declarations instead of
  blanket `import(terra)` / `import(methods)`; the two previously
  unqualified
  [`subset()`](https://rspatial.github.io/terra/reference/subset.html) /
  [`aggregate()`](https://rspatial.github.io/terra/reference/aggregate.html)
  calls are now `terra::`-qualified.

## geomattR 0.2.0

Breaking changes to documented metric contracts:

- `bearing` is now documented as an **axial orientation** in \[-90, 90\]
  degrees: the maximum-length line is always oriented from its
  southernmost to its northernmost endpoint, so values outside that
  range were unreachable. 0 = north-south axis, -90/90 = east-west axis.
  Computed values are unchanged.
- `northerness = cos(bearing)` is now documented to range in \[0, 1\];
  negative values were unreachable.
- `fractaldimension` now follows the FRAGSTATS convention
  `2 * log(0.25 * P) / log(A)` (McGarigal & Marks 1995,
  <doi:10.2737/PNW-GTR-351>). **Values change** relative to the previous
  `2 * log(P) / log(A)`, which could fall outside \[1, 2\] for small
  polygons.
- `hole_area_pct` now uses the **gross** area (including holes) as
  denominator, matching its documentation. **Values change** relative to
  the previous net-area denominator.
- `decimallongitude` / `decimallatitude` are now always in decimal
  degrees: the centroid is reprojected to EPSG:4326 when the input CRS
  is projected. Previously, `method = "cosine"` on a projected CRS
  returned metres under these column names.

Other fixes and improvements:

- Documentation no longer describes `method = "cosine"` as “for planar
  CRS”. `geo`, `haversine` and `cosine` are all lon/lat great-circle
  methods in
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html);
  on a projected CRS the argument is ignored and distances are
  Cartesian.
- [`calc_elongation()`](https://gortegasolis.github.io/geomattR/reference/calc_elongation.md)
  computes rectangle side lengths explicitly from the unique corners in
  ring order, instead of relying on undocumented ordering of
  [`terra::crds()`](https://rspatial.github.io/terra/reference/crds.html)
  output, and returns `Inf` for degenerate (zero-width) rectangles
  instead of failing or dividing by zero.
- Removed the no-op `transform` argument passed to
  [`terra::expanse()`](https://rspatial.github.io/terra/reference/expanse.html);
  area is geodesic on lon/lat input and Cartesian on projected input.
- `num_holes` is counted from the `hole` column of
  [`terra::geom()`](https://rspatial.github.io/terra/reference/geometry.html)
  instead of [`length()`](https://rdrr.io/r/base/length.html) on the
  [`fillHoles()`](https://rspatial.github.io/terra/reference/fill.html)
  result; `num_polygons` uses
  [`nrow()`](https://rspatial.github.io/terra/reference/dimensions.html).
- New input validation: clear error for zero-row inputs, warning for
  invalid geometries, and a warning when a hull spans more than 180
  degrees of longitude (antimeridian), where bounding-box extents are
  unreliable.

## geomattR 0.1.2

- Fixed `"subscript out of bounds"` error in
  `calc_extent(direction = <single>, output = "polygon", by_feature = TRUE)`.
- Added R CMD check continuous integration via GitHub Actions.
- Declared `parallel` in `Imports` (used by
  [`calculate_geometric_attributes()`](https://gortegasolis.github.io/geomattR/reference/calculate_geometric_attributes.md)).
- `inst/CITATION` now uses the installed package version instead of a
  hardcoded one.

## geomattR 0.1.1

- Initial public release.
