# geomattR: Calculate Geometric Attributes of Spatial Polygons

Calculate geometric attributes of spatial polygons. Computes area,
perimeter, compactness, elongation, orientation, fractal dimension, and
shape indices suitable for geospatial analysis, urban planning, and
environmental science applications.

By default, measurements use geodesic calculations for accuracy across
large study regions (i.e. continental scale studies). The package
supports the `"geo"`, `"haversine"`, and `"cosine"` methods and
automatically handles geographic (lon/lat) and projected CRS
appropriately.

## Details

### Main Functions

- [`calculate_geometric_attributes()`](https://gortegasolis.github.io/geomattR/reference/calculate_geometric_attributes.md):
  Calculate metrics for one or more polygons. Runs sequentially by
  default; pass a `cl` argument for parallel execution.

### Helper Functions

- [`get_distant_points()`](https://gortegasolis.github.io/geomattR/reference/get_distant_points.md):
  Find most distant points on convex hull

- [`calc_elongation()`](https://gortegasolis.github.io/geomattR/reference/calc_elongation.md):
  Calculate elongation ratio

- [`calc_extent()`](https://gortegasolis.github.io/geomattR/reference/calc_extent.md):
  Calculate east-west and north-south extents

### Geodesic Measurements

All calculations prioritize accuracy:

- **Area & Perimeter**: Geodesic by default; projected input is handled
  transparently for methods that need geographic coordinates

- **Distances**: Support `method = "geo"`, `"haversine"`, and
  `"cosine"`. All three are lon/lat great-circle methods; on a projected
  CRS,
  [`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
  ignores `method` and computes Cartesian distances

- **Bearing**: Computed from geographic coordinates when needed

- **Automatic Projection**: Non-geographic CRS are handled transparently

Precise definitions of each reported metric are documented in
[`calculate_geometric_attributes()`](https://gortegasolis.github.io/geomattR/reference/calculate_geometric_attributes.md).

### Example

    library(geomattR)
    library(terra)

    # Create sample polygon in WGS84
    coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
    polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")

    # Calculate all attributes (geodesic by default)
    result <- calculate_geometric_attributes(polygon)

    # Calculate specific metrics
    result <- calculate_geometric_attributes(polygon,
      metrics = c("area", "perimeter", "compactness"))

    # Parallel processing
    cl <- parallel::makeCluster(2)
    result <- calculate_geometric_attributes(polygon, cl = cl)
    parallel::stopCluster(cl)

## Acknowledgment

This package began as a side project during my time as a technician on
[BEAST – BiodivErsity dynamics Across a continuum of Space, Time, and
their
scales](https://www.fzp.czu.cz/en/r-9411-projects-and-partnerships/r-9880-projects/r-18897-beast-biodiversity-dynamics-across-a-continuum-of-space-time-and-their-scales),
led by Petr Keil, and was therefore partially funded by the European
Union (ERC, BEAST, grant no. 101044740). Views and opinions expressed
are those of the author(s) only and do not necessarily reflect those of
the European Union or the European Research Council Executive Agency;
neither the European Union nor the granting authority can be held
responsible for them.

Discussions with P. Keil on spatial and geometric problems inspired the
package. G. Ortega-Solís developed all core functions; Claude Code was
used to double-check the code and to help write unit tests.

## See also

Useful links:

- <https://github.com/gortegasolis/geomattR>

- Report bugs at <https://github.com/gortegasolis/geomattR/issues>

## Author

**Maintainer**: Gabriel Ortega-Solís <g.ortega.solis@geomattr.org>
([ORCID](https://orcid.org/0000-0002-0516-5694)) \[copyright holder\]

Authors:

- Gabriel Ortega-Solís <g.ortega.solis@geomattr.org>
  ([ORCID](https://orcid.org/0000-0002-0516-5694)) \[copyright holder\]
