#' Calculate Geometric Attributes of Spatial Polygons
#'
#' Calculates a comprehensive set of geometric attributes for
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
#' @param method Character string specifying the method for calculations.
#' @param by_feature Logical. If \code{TRUE} (default), compute metrics for each
#'   feature independently. If \code{FALSE}, non-spatial columns are dropped,
#'   features are dissolved into a single geometry, and one set of metrics is
#'   returned.
#'
#' @return The input SpatVector with additional columns containing the requested
#'   geometric attributes:
#'   \itemize{
#'     \item \code{area}: Total area in square meters. Wrapper around `terra::expanse()`.
#'     \item \code{perimeter}: Total perimeter length in meters. Wrapper around `terra::perim()`.
#'     \item \code{compactness}: Polsby-Popper compactness.
#'     \item \code{reock}: Reock compactness.
#'     \item \code{elongation_rectangle}: Elongation index from the minimum
#'       bounding rectangle.
#'     \item \code{num_holes}: Number of holes (interior rings) in the polygon.
#'     \item \code{hole_area}: Total area of holes in square meters.
#'     \item \code{hole_area_pct}: Percentage of total area occupied by holes.
#'     \item \code{num_polygons}: Number of separate polygon parts (multi-part count).
#'     \item \code{ew_length}: East-west extent in meters.
#'     \item \code{ns_length}: North-south extent in meters.
#'     \item \code{maxlength}: Maximum Feret distance across the convex hull.
#'     \item \code{bearing}: Geographic bearing of the maximum length line from southernmost to northernmost point in decimal degrees.
#'     \item \code{northerness}: Northerness component of bearing.
#'     \item \code{fractaldimension}: Boundary complexity index.
#'     \item \code{sinuosity}: Perimeter-to-maximum-length ratio.
#'     \item \code{shape_index}: Dimensionless irregularity index.
#'     \item \code{circularity_ratio}: Circularity index based on area and
#'       maximum hull distance.
#'     \item \code{decimallongitude}: Centroid longitude in decimal degrees.
#'     \item \code{decimallatitude}: Centroid latitude in decimal degrees.
#'   }
#'
#' @details
#' Each polygon is processed independently via the internal function
#' \code{.calculate_geometric_attributes_single}, which handle a 
#' single feature at a time, but it is optimized to ensure that intermediate objects 
#' required for multiple metrics (convex hull, minimum circle, etc.) are computed only 
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
#' The function supports the methods \code{"geo"} (default), \code{"haversine"} (less precise but fast 
#' alternative to `geo`), and \code{"cosine"} (for planar CRS).
#' Inputs are internally projected to EPSG:4326 when a metric requires
#' geographic coordinates and restored to the original CRS on return when
#' applicable.
#'
#' \strong{Scope of the \code{method} parameter:}
#' The \code{method} argument is passed to \code{terra::distance()} for
#' distance-based metrics (extent, maxlength, and elongation). Area
#' (\code{terra::expanse()}) and perimeter (\code{terra::perim()}) use
#' terra's built-in CRS-dependent calculations: geodesic for geographic
#' (lon/lat) CRS, Cartesian for projected CRS. When \code{method = "geo"} or
#' \code{"haversine"} and the input has a projected CRS, the geometry is
#' temporarily reprojected to EPSG:4326 where required by downstream metrics.
#'
#' \strong{Size metrics:}
#' \itemize{
#'   \item Area: geodesic by default; handled according to the selected method.
#'   \item Perimeter: geodesic by default; handled according to the selected method.
#'   \item East-west extent:
#'     \eqn{\bar{D}_{EW} = \frac{d(NW, NE) + d(SW, SE)}{2}}{D_EW = (d(NW, NE) + d(SW, SE)) / 2}.
#'   \item North-south extent:
#'     \eqn{\bar{D}_{NS} = \frac{d(SW, NW) + d(SE, NE)}{2}}{D_NS = (d(SW, NW) + d(SE, NE)) / 2}.
#'   \item Maximum length (Feret diameter):
#'     \eqn{L_{\max} = \max_{p_i, p_j} d(p_i, p_j)}{L_max = max d(p_i, p_j)}.
#' }
#'
#' \strong{Shape metrics:}
#' \itemize{
#'   \item Compactness (Polsby-Popper): area normalized by perimeter, relative
#'     to a circle:
#'     \eqn{C = \frac{4\pi A}{P^2}}{C = (4 * pi * A) / P^2}.
#'   \item Reock compactness:
#'     \eqn{R = \frac{A}{A_{MEC}}}{R = A / A_MEC}.
#'   \item Shape index (perimeter relative to a circle of equal area):
#'     \eqn{SI = \frac{P}{2\sqrt{\pi A}}}{SI = P / (2 * sqrt(pi * A))}.
#'   \item Circularity ratio:
#'     \eqn{CR = \frac{4A}{\pi L_{\max}^2}}{CR = (4 * A) / (pi * L_max^2)}.
#'   \item Fractal dimension:
#'     \eqn{D = 2 \times \frac{\ln(P)}{\ln(A)}}{D = 2 * log(P) / log(A)}.
#'   \item Sinuosity:
#'     \eqn{S = \frac{P}{L_{\max}}}{S = P / L_max}.
#' }
#'
#' \strong{Orientation metrics:}
#' \itemize{
#'   \item Bearing: orientation of the longest axis; computed from geographic
#'     coordinates when needed.
#'   \item Northerness:
#'     \eqn{N = \cos(\text{bearing} \times \frac{\pi}{180})}{N = cos(bearing * pi / 180)}.
#'   \item Elongation: ratio of major to minor axis of the minimum bounding
#'     rectangle. Elongation is calculated as the ratio of the mean of the two
#'     largest side lengths to the mean of the two shortest side lengths:
#'     \eqn{E = \frac{\text{mean}(\text{long sides})}{\text{mean}(\text{short sides})}}.
#' }
#'
#' \strong{Hole and part metrics:}
#' \itemize{
#'   \item Hole area percentage:
#'     \eqn{HA\% = \frac{A_{\text{holes}}}{A} \times 100}{HA\% = (A_holes / A) * 100}.
#'   \item \code{num_holes}, \code{hole_area}, and \code{num_polygons} are direct
#'     counts/areas derived from polygon topology.
#' }
#'
#' @references
#'
#' Reock, E. C. (1961). Measuring compactness as a requirement of legislative apportionment. \emph{Midwest Journal of Political Science}, 5(1), 70-74. \doi{10.2307/2109043}
#'
#' Dražić, Slobodan, Nebojša Ralević, and Joviša Žunić. Shape Elongation from Optimal Encasing Rectangles. \emph{Computers & Mathematics with Applications 60, no. 7 (2010): 2035–42}. \doi{10.1016/j.camwa.2010.07.043}.
#' 
#' @export
#'
#' @examples
#' library(terra)
#'
#' # Create a sample 1-degree square polygon near the equator
#' coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
#' polygons <- vect(coords, type = "polygon", crs = "EPSG:4326")
#'
#' # Sequential processing (default)
#' result <- calculate_geometric_attributes(polygons)
#'
#' # Calculate specific metrics only
#' result <- calculate_geometric_attributes(polygons,
#'   metrics = c("area", "perimeter", "compactness")
#' )
#'
#' \dontrun{
#' # Parallel processing with an explicit cluster (use small number of cores for checks)
#' cl <- parallel::makeCluster(2)
#' result <- calculate_geometric_attributes(polygons, cl = cl)
#' parallel::stopCluster(cl)
#' }
calculate_geometric_attributes <- function(v, metrics = "all", cl = NULL, method = "geo", by_feature = TRUE) {
  # Validate input
  if (!methods::is(v, "SpatVector")) {
    if (methods::is(v, "sf")) {
      v <- terra::vect(v)
    } else {
      cli::cli_abort("{.arg v} must be a SpatVector or sf object", call = rlang::caller_env())
    }
  }

  if (!by_feature) {
    cli::cli_warn(c(
      "{.arg by_feature} is {.val FALSE}.",
      "i" = "Non-spatial columns will be dropped and features dissolved into a single geometry."
    ))
    v <- subset(v, subset = TRUE, select = NULL)
    v <- aggregate(v, by = NULL, dissolve = TRUE)
  }

  n_features <- nrow(v)

  # Single feature: process directly
  if (n_features == 1L) {
    return(.calculate_geometric_attributes_single(v, metrics = metrics, method = method))
  }

  # Split the SpatVector into individual features
  feature_list <- lapply(seq_len(n_features), function(i) v[i, ])

  if (is.null(cl)) {
    # --- Sequential processing ---
    results <- lapply(feature_list, function(poly) {
      .calculate_geometric_attributes_single(poly, metrics = metrics, method = method)
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
        ".calculate_geometric_attributes_single",
        "calc_elongation",
        "calc_extent",
        "get_distant_points"
      ),
      envir = asNamespace("geomattR")
    )

    # Wrap terra objects before shipping to workers to avoid pointer serialization issues
    wrapped_features <- lapply(feature_list, terra::wrap)

    results <- parallel::parLapply(cl, wrapped_features, function(wpoly) {
      poly <- terra::unwrap(wpoly)
      out <- .calculate_geometric_attributes_single(poly, metrics = metrics, method = method)
      terra::wrap(out)
    })

    # Unwrap worker results back on the master process
    results <- lapply(results, terra::unwrap)
  }

  # Combine results back into a single SpatVector
  do.call(rbind, results)
}
