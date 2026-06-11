#' Calculate Geometric Attributes for a Single Polygon
#'
#' Calculates geometric attributes for exactly one polygon feature. This is the
#' core computational function used internally by
#' \code{\link{calculate_geometric_attributes}}.
#'
#' @param v A SpatVector object containing exactly one polygon feature.
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
#'   (see Details for descriptions).
#'
#' @return The input SpatVector with additional columns containing the requested
#'   geometric attributes.
#'
#' @details
#' This function is optimized to process a single polygon. It computes
#' intermediate geometric objects (convex hull, centroid, etc.) only once and
#' reuses them across dependent metrics, avoiding redundant computation.
#'
#' Metric dependencies are resolved automatically: requesting a derived metric
#' (e.g., \code{"sinuosity"}) will internally compute its prerequisites
#' (\code{perimeter}, \code{maxlength}) even if they are not explicitly
#' requested.
#'
#' \strong{Geodesic Measurements:}
#' All measurements use geodesic calculations for accuracy across different
#' coordinate systems. The input is internally projected to EPSG:4326 for
#' computation and restored to its original CRS before returning.
#'
#' \itemize{
#'   \item \strong{area}: Total area in square meters (geodesic via
#'     \code{terra::expanse()}).
#'   \item \strong{perimeter}: Total perimeter in meters (geodesic via
#'     \code{terra::perim()}).
#'   \item \strong{compactness}: Polsby-Popper formula:
#'     \eqn{(4\pi \cdot A) / P^2}{(4*pi*A)/P^2}. Values 0--1; 1 = circle.
#'   \item \strong{reock}: Ratio of polygon area to minimum enclosing circle area.
#'   \item \strong{elongation_rectangle}: Major/minor axis ratio of the minimum
#'     bounding rectangle.
#'   \item \strong{num_holes}: Count of interior rings (holes).
#'   \item \strong{hole_area}: Total hole area in square meters.
#'   \item \strong{hole_area_pct}: Percentage of total area occupied by holes.
#'   \item \strong{num_polygons}: Number of parts in a multi-part polygon.
#'   \item \strong{ew_length}: Average east-west extent in meters (geodesic).
#'   \item \strong{ns_length}: Average north-south extent in meters (geodesic).
#'   \item \strong{maxlength}: Maximum geodesic distance across the convex hull.
#'   \item \strong{bearing}: Bearing (degrees) from southernmost to northernmost
#'     hull vertex.
#'   \item \strong{northerness}: \eqn{\cos(\text{bearing} \cdot \pi / 180)}{cos(bearing*pi/180)}.
#'   \item \strong{fractaldimension}: \eqn{2 \log(P) / \log(A)}{2*log(P)/log(A)}.
#'   \item \strong{sinuosity}: Perimeter / maxlength.
#'   \item \strong{shape_index}: \eqn{P / (2\sqrt{\pi A})}{P/(2*sqrt(pi*A))}.
#'   \item \strong{circularity_ratio}: \eqn{4A / (\pi \cdot L^2)}{4A/(pi*L^2)}
#'     where L = maxlength.
#'   \item \strong{decimallongitude}: Centroid longitude (decimal degrees).
#'   \item \strong{decimallatitude}: Centroid latitude (decimal degrees).
#' }
#'
#' For processing multiple polygons use
#' \code{\link{calculate_geometric_attributes}} which wraps this function and
#' supports both sequential and parallel execution.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#'
#' # Load a single polygon
#' polygon <- vect("path/to/polygon.shp")[1, ]
#'
#' # Calculate all attributes
#' result <- calculate_geometric_attributes_single(polygon)
#'
#' # Calculate only specific metrics
#' result <- calculate_geometric_attributes_single(polygon,
#'   metrics = c("area", "perimeter", "compactness"))
#' }
calculate_geometric_attributes_single <- function(v, metrics = "all") {
  # Validate input
  if (!methods::is(v, "SpatVector")) {
    stop("'v' must be a SpatVector object")
  }

  if (nrow(v) != 1) {
    stop(
      "Input must contain exactly one polygon. Received ",
      nrow(v),
      " features."
    )
  }

  verbatimCRS <- terra::crs(v)
  v <- terra::project(v, "EPSG:4326")


  # Define all available metrics
  available_metrics <- c(
    "area", "perimeter", "compactness", "reock",
    "elongation_rectangle", "num_holes", "hole_area", "hole_area_pct",
    "num_polygons", "ew_length", "ns_length", "maxlength", "bearing",
    "northerness", "fractaldimension", "sinuosity", "shape_index",
    "circularity_ratio", "decimallongitude", "decimallatitude"
  )

  # Validate and normalize metrics parameter
  if (!is.character(metrics)) {
    stop("'metrics' must be a character string or vector")
  }

  if (length(metrics) == 1L && metrics == "all") {
    metrics_to_calc <- available_metrics
  } else {
    invalid_metrics <- setdiff(metrics, available_metrics)
    if (length(invalid_metrics) > 0) {
      stop(
        "Invalid metric names: ",
        paste(invalid_metrics, collapse = ", "),
        "\nAvailable metrics: ",
        paste(available_metrics, collapse = ", ")
      )
    }
    metrics_to_calc <- metrics
  }

  # --- Resolve implicit dependencies ---
  # Some metrics depend on intermediate values that must be computed first.

  need_area <- any(
    c("area", "hole_area_pct", "compactness", "reock",
      "fractaldimension", "shape_index", "circularity_ratio") %in% metrics_to_calc
  )
  need_perimeter <- any(
    c("perimeter", "compactness", "fractaldimension",
      "sinuosity", "shape_index") %in% metrics_to_calc
  )
  need_maxlength <- any(
    c("maxlength", "sinuosity", "circularity_ratio") %in% metrics_to_calc
  )
  need_bearing <- any(
    c("bearing", "northerness") %in% metrics_to_calc
  )
  need_hole_area <- any(
    c("hole_area", "hole_area_pct") %in% metrics_to_calc
  )

  # Determine which intermediate objects are needed
  need_hull <- need_maxlength || need_bearing ||
    any(c("elongation_rectangle", "ew_length", "ns_length") %in% metrics_to_calc)
  need_distant_pts <- need_maxlength || need_bearing
  need_centroid <- any(c("decimallongitude", "decimallatitude") %in% metrics_to_calc)
  need_mincircle <- "reock" %in% metrics_to_calc
  need_inh <- any(c("num_holes", "hole_area", "hole_area_pct") %in% metrics_to_calc)
  need_pols <- "num_polygons" %in% metrics_to_calc

  # --- Compute intermediate objects (each at most once) ---

  hull <- NULL
  if (need_hull) {
    hull <- terra::hull(v, type = "convex")
  }

  distant_pts <- NULL
  if (need_distant_pts) {
    # Pass the pre-computed hull to avoid redundant computation
    distant_pts <- get_distant_points(v, hull = hull)
  }

  centroid <- NULL
  if (need_centroid) {
    centroid <- terra::centroids(v)
  }

  mincircle <- NULL
  if (need_mincircle) {
    mincircle <- terra::hull(v, type = "circle")
  }

  inh <- NULL
  if (need_inh) {
    inh <- terra::fillHoles(v, inverse = TRUE)
  }

  pols <- NULL
  if (need_pols) {
    pols <- terra::disagg(v)
  }

  # --- Compute base metrics ---

  area_val <- NULL
  if (need_area) {
    area_val <- terra::expanse(v, unit = "m", transform = TRUE)
  }

  perimeter_val <- NULL
  if (need_perimeter) {
    perimeter_val <- terra::perim(v)
  }

  maxlength_val <- NULL
  if (need_maxlength) {
    maxlength_val <- distant_pts$distance
  }

  bearing_val <- NULL
  if (need_bearing) {
    bearing_val <- distant_pts$bearing
  }

  hole_area_val <- NULL
  if (need_hole_area) {
    hole_area_val <- sum(terra::expanse(inh, unit = "m", transform = TRUE))
  }

  # --- Assign requested metrics to the output ---

  if ("area" %in% metrics_to_calc) {
    v$area <- area_val
  }

  if ("perimeter" %in% metrics_to_calc) {
    v$perimeter <- perimeter_val
  }

  if ("compactness" %in% metrics_to_calc) {
    v$compactness <- (4 * pi * area_val) / (perimeter_val^2)
  }

  if ("reock" %in% metrics_to_calc) {
    v$reock <- area_val / terra::expanse(mincircle, unit = "m", transform = TRUE)
  }

  if ("elongation_rectangle" %in% metrics_to_calc) {
    v$elongation_rectangle <- calc_elongation(v, hull = hull)
  }

  if ("num_holes" %in% metrics_to_calc) {
    v$num_holes <- length(inh)
  }

  if ("hole_area" %in% metrics_to_calc) {
    v$hole_area <- hole_area_val
  }

  if ("hole_area_pct" %in% metrics_to_calc) {
    v$hole_area_pct <- (hole_area_val / area_val) * 100
  }

  if ("num_polygons" %in% metrics_to_calc) {
    v$num_polygons <- length(pols)
  }

  if ("ew_length" %in% metrics_to_calc) {
    v$ew_length <- calc_extent_ew(v)
  }

  if ("ns_length" %in% metrics_to_calc) {
    v$ns_length <- calc_extent_ns(v)
  }

  if ("maxlength" %in% metrics_to_calc) {
    v$maxlength <- maxlength_val
  }

  if ("bearing" %in% metrics_to_calc) {
    v$bearing <- bearing_val
  }

  if ("northerness" %in% metrics_to_calc) {
    v$northerness <- cos(pi * (bearing_val / 180))
  }

  if ("fractaldimension" %in% metrics_to_calc) {
    v$fractaldimension <- 2 * (log(perimeter_val) / log(area_val))
  }

  if ("sinuosity" %in% metrics_to_calc) {
    v$sinuosity <- perimeter_val / maxlength_val
  }

  if ("shape_index" %in% metrics_to_calc) {
    v$shape_index <- perimeter_val / (2 * sqrt(pi * area_val))
  }

  if ("circularity_ratio" %in% metrics_to_calc) {
    v$circularity_ratio <- (4 * area_val) / (pi * maxlength_val^2)
  }

  if ("decimallongitude" %in% metrics_to_calc) {
    v$decimallongitude <- terra::crds(centroid)[, 1]
  }

  if ("decimallatitude" %in% metrics_to_calc) {
    v$decimallatitude <- terra::crds(centroid)[, 2]
  }

  # Restore original CRS
  v <- terra::project(v, verbatimCRS)

  return(v)
}
