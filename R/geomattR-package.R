#' geomattR: Calculate Geometric Attributes of Spatial Polygons
#'
#' @description
#' Calculate geometric attributes of spatial polygons. Computes area, perimeter, 
#' compactness, elongation, orientation, fractal dimension, and shape indices suitable 
#' for geospatial analysis, urban planning, and environmental science applications.
#'
#' By default, measurements use geodesic calculations for accuracy across
#' large study regions (i.e. continental scale studies). The package supports the
#' \code{"geo"}, \code{"haversine"}, and \code{"cosine"} methods and
#' automatically handles geographic (lon/lat) and projected CRS appropriately.
#'
#' @details
#'
#' ## Main Functions
#'
#' - [calculate_geometric_attributes()]: Calculate metrics for one or more
#'   polygons. Runs sequentially by default; pass a `cl` argument for parallel
#'   execution.
#'
#' ## Helper Functions
#'
#' - [get_distant_points()]: Find most distant points on convex hull
#' - [calc_elongation()]: Calculate elongation ratio
#' - [calc_extent()]: Calculate east-west and north-south extents
#'
#' ## Geodesic Measurements
#'
#' All calculations prioritize accuracy:
#'
#' - **Area & Perimeter**: Geodesic by default; projected input is handled
#'   transparently for methods that need geographic coordinates
#' - **Distances**: Support `method = "geo"`, `"haversine"`, and `"cosine"`.
#'   All three are lon/lat great-circle methods; on a projected CRS,
#'   `terra::distance()` ignores `method` and computes Cartesian distances
#' - **Bearing**: Computed from geographic coordinates when needed
#' - **Automatic Projection**: Non-geographic CRS are handled transparently
#'
#' Precise definitions of each reported metric are documented in
#' [calculate_geometric_attributes()].
#'
#' ## Example
#'
#' ```r
#' library(geomattR)
#' library(terra)
#'
#' # Create sample polygon in WGS84
#' coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
#' polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")
#'
#' # Calculate all attributes (geodesic by default)
#' result <- calculate_geometric_attributes(polygon)
#'
#' # Calculate specific metrics
#' result <- calculate_geometric_attributes(polygon,
#'   metrics = c("area", "perimeter", "compactness"))
#'
#' # Parallel processing
#' cl <- parallel::makeCluster(2)
#' result <- calculate_geometric_attributes(polygon, cl = cl)
#' parallel::stopCluster(cl)
#' ```
#'
#' @importFrom terra aggregate centroids crds crs disagg distance expanse ext
#'   fillHoles geom geomtype hull is.lonlat is.valid perim project subset
#'   unwrap vect wrap
#' @importFrom methods is
#' @importFrom geosphere bearing
#'
#' @keywords internal
"_PACKAGE"
