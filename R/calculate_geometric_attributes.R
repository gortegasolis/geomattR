#' Calculate Geometric Attributes of Spatial Polygons
#'
#' Calculates a comprehensive set of geometric and morphometric attributes for
#' spatial polygon features. Supports both sequential and parallel execution
#' through an optional cluster argument.
#'
#' @param v A SpatVector object representing one or more polygons.
#' @param metrics Character string or vector specifying which metrics to calculate.
#'   Options are:
#'   \itemize{
#'     \item \code{"all"} (default): Calculate all available metrics
#'     \item A single metric name as a string: Calculate only that metric
#'     \item A character vector of metric names: Calculate specified metrics
#'   }
#'   Available metric names: "area", "perimeter", "compactness", "reock",
#'   "elongation_rectangle", "num_holes", "hole_area", "hole_area_pct",
#'   "num_polygons", "ew_length", "ns_length", "maxlength", "bearing",
#'   "northerness", "fractaldimension", "sinuosity", "shape_index",
#'   "circularity_ratio", "decimallongitude", "decimallatitude"
#'
#' @param cl A cluster object created by \code{\link[parallel]{makeCluster}}, or
#'   \code{NULL} (default). When \code{NULL} features are processed sequentially.
#'   Passing a cluster enables parallel processing across the cluster workers.
#'
#' @return The input SpatVector with additional columns containing the requested
#'   geometric attributes:
#'   \itemize{
#'     \item \code{area}: Total area in square meters
#'     \item \code{perimeter}: Total perimeter length in meters
#'     \item \code{compactness}: Polsby-Popper compactness (1 = perfect circle)
#'     \item \code{reock}: Reock compactness (area / minimum enclosing circle area)
#'     \item \code{elongation_rectangle}: Elongation ratio based on minimum bounding rectangle
#'     \item \code{num_holes}: Number of holes (interior rings) in the polygon
#'     \item \code{hole_area}: Total area of holes in square meters
#'     \item \code{hole_area_pct}: Percentage of total area occupied by holes
#'     \item \code{num_polygons}: Number of separate polygon parts (multi-part count)
#'     \item \code{ew_length}: Average east-west extent in meters
#'     \item \code{ns_length}: Average north-south extent in meters
#'     \item \code{maxlength}: Maximum distance across convex hull in meters
#'     \item \code{bearing}: Geographic bearing of maximum length line in degrees
#'     \item \code{northerness}: Northerness component of bearing (-1 to 1)
#'     \item \code{fractaldimension}: Fractal dimension (complexity measure, typically 1-2)
#'     \item \code{sinuosity}: Sinuosity (perimeter to maximum length ratio)
#'     \item \code{shape_index}: Shape index (deviation from circular shape)
#'     \item \code{circularity_ratio}: Circularity based on maximum length
#'     \item \code{decimallongitude}: Centroid longitude in decimal degrees
#'     \item \code{decimallatitude}: Centroid latitude in decimal degrees
#'   }
#'
#' @details
#' Each polygon is processed independently via
#' \code{\link{calculate_geometric_attributes_single}}, which ensures that
#' intermediate objects (convex hull, minimum circle, etc.) are computed only
#' once per feature.
#'
#' \strong{Sequential vs. Parallel:}
#' \itemize{
#'   \item When \code{cl = NULL} (default), features are processed sequentially
#'     with \code{\link[base]{lapply}}.
#'   \item When \code{cl} is a valid cluster, features are distributed across
#'     workers via \code{\link[parallel]{parLapply}}. The function handles
#'     library loading and function export to the cluster automatically.
#' }
#'
#' \strong{Geodesic Measurements:}
#' All measurements use geodesic calculations for accuracy regardless of input
#' CRS. Inputs are internally projected to EPSG:4326 for computation and
#' restored to the original CRS on return.
#'
#' \strong{Size metrics:}
#' \itemize{
#'   \item Area: \code{terra::expanse()} with \code{transform = TRUE}.
#'   \item Perimeter: \code{terra::perim()} on the geographic representation.
#'   \item Extents (EW, NS): geodesic distances between bounding-box corners.
#' }
#'
#' \strong{Shape metrics:}
#' \itemize{
#'   \item Compactness (Polsby-Popper): how circular the polygon is.
#'   \item Shape index and circularity ratio: alternative shape characterizations.
#'   \item Fractal dimension: boundary complexity.
#' }
#'
#' \strong{Orientation metrics:}
#' \itemize{
#'   \item Bearing: orientation of the longest axis.
#'   \item Northerness: cosine of bearing; ranges from -1 (south) to 1 (north).
#'   \item Elongation: ratio of major to minor axis of the minimum bounding
#'     rectangle.
#' }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#'
#' # Load polygon shapefile
#' polygons <- vect("path/to/polygons.shp")
#'
#' # Sequential processing (default)
#' result <- calculate_geometric_attributes(polygons)
#'
#' # Calculate specific metrics only
#' result <- calculate_geometric_attributes(polygons,
#'   metrics = c("area", "perimeter", "compactness"))
#'
#' # Parallel processing with an explicit cluster
#' cl <- parallel::makeCluster(parallel::detectCores() - 1)
#' result <- calculate_geometric_attributes(polygons, cl = cl)
#' parallel::stopCluster(cl)
#' }
calculate_geometric_attributes <- function(v, metrics = "all", cl = NULL) {
  # Validate input
  if (!methods::is(v, "SpatVector")) {
    stop("'v' must be a SpatVector object")
  }

  n_features <- nrow(v)

  # Single feature: process directly (no overhead from split/combine)
  if (n_features == 1L) {
    return(calculate_geometric_attributes_single(v, metrics = metrics))
  }

  # Split the SpatVector into individual features
  feature_list <- lapply(seq_len(n_features), function(i) v[i, ])

  if (is.null(cl)) {
    # --- Sequential processing ---
    results <- lapply(feature_list, function(poly) {
      calculate_geometric_attributes_single(poly, metrics = metrics)
    })
  } else {
    # --- Parallel processing ---
    # Prepare cluster: load packages and export required functions
    parallel::clusterEvalQ(cl, {
      library(terra)
      library(geosphere)
    })
    parallel::clusterExport(
      cl,
      c(
        "calculate_geometric_attributes_single",
        "calc_elongation",
        "calc_extent_ew",
        "calc_extent_ns",
        "get_distant_points"
      ),
      envir = asNamespace("geomattR")
    )

    results <- parallel::parLapply(cl, feature_list, function(poly) {
      calculate_geometric_attributes_single(poly, metrics = metrics)
    })
  }

  # Combine results back into a single SpatVector
  do.call(rbind, results)
}
