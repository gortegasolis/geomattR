#' geomattR: Calculate Geometric Attributes of Spatial Polygons
#'
#' @description
#' Calculate geometric and morphometric attributes of spatial polygons with
#' geodesic accuracy. Computes area, perimeter, compactness, elongation,
#' orientation, fractal dimension, and shape indices suitable for geospatial
#' analysis, urban planning, and environmental science applications.
#'
#' All measurements use geodesic calculations for accuracy across different
#' coordinate reference systems. The package automatically handles both
#' geographic (lon/lat) and projected CRS appropriately.
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
#' - **Area & Perimeter**: Use `terra::expanse()` with explicit
#'   `transform = TRUE` for automatic geodesic calculation; perimeter
#'   is computed on the EPSG:4326 representation
#' - **Distances**: Use explicit `method = "geo"` for geodesic calculations
#' - **Automatic Projection**: Non-geographic CRS are handled transparently
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
#' @import terra
#' @import methods
#' @importFrom geosphere bearing
#'
#' @keywords internal
"_PACKAGE"
