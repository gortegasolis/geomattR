#' Calculate Geometric Attributes for a Single Polygon
#'
#' Calculates geometric attributes for exactly one polygon feature. This is the
#' core computational function used by \code{\link{calculate_geometric_attributes}} and
#' \code{\link{calculate_geometric_attributes_parallel}}.
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
#'  (see Details for descriptions).
#'
#' @return The input SpatVector with additional columns containing the requested
#'   geometric attributes.
#'
#' @details
#' This function is optimized to process a single polygon and only computes
#' intermediate geometric objects (convex hull, centroid, etc.) that are needed
#' for the requested metrics.
#'
#' \strong{Geodesic Measurements:}
#' All measurements use geodesic calculations for accuracy across different coordinate systems.
#' Area calculations use \code{terra::expanse()} with automatic lon/lat transformation.
#' Perimeter calculations explicitly project to lon/lat (EPSG:4326) if the input is not already
#' in a geographic CRS, ensuring accurate geodesic measurements as recommended by terra documentation.
#' Distance-based metrics (maxlength, ew_length, ns_length, bearing) use explicit geodesic
#' distance calculations via \code{method = "geo"}.
#'
#' Area returns the total area in square meters using geodesic methods.
#' Perimeter returns the total perimeter length in meters using geodesic methods.
#' Compactness is calculated using the Polsby-Popper formula: (4 * pi * Area) / (Perimeter^2). The formula produces values between 0 and 1, where 1 indicates a perfect circle.
#' Reock compactness is calculated as the ratio of the polygon's area to the area of its minimum enclosing circle.
#' Elongation ratio is calculated as the ratio of the polygon's length to its width based on the minimum bounding rectangle.
#' Number of holes counts the number of interior holes within the polygon.
#' Hole area returns the total area of all interior holes in square meters using geodesic methods.
#' Hole area percentage calculates the percentage of the polygon's total area that is occupied by holes.
#' Number of polygons counts the number of separate polygon parts in a multi-part polygon.
#' East-West length returns the average east-west extent of the polygon in meters based on the geographic bounding box aligned with the cardinal directions, using geodesic distance calculations.
#' North-South length returns the average north-south extent of the polygon in meters based on the geographic bounding box aligned with the cardinal directions, using geodesic distance calculations.
#' Maximum length returns the maximum distance in meters between a pair of opposite vertices across the polygon's convex hull, using geodesic calculations.
#' Bearing returns the geographic bearing in degrees from the southernmost to the northernmost point of the polygon's convex hull.
#' Northerness calculates the cosine of the bearing angle (in radians) to quantify the northward orientation of the polygon.
#' Fractal dimension is calculated using the formula: 2 * (log(Perimeter) / log(Area)), providing a measure of shape complexity.
#' Sinuosity is calculated as the ratio of the polygon's perimeter to its maximum length.
#' Shape index is calculated as: Perimeter / (2 * sqrt(pi * Area)), providing a dimensionless measure of shape complexity.
#' Circularity ratio is calculated as: (4 * Area) / (pi * Maximum Length^2), indicating how closely the shape resembles a circle.
#' Decimal longitude returns the centroid's longitude in decimal degrees.
#' Decimal latitude returns the centroid's latitude in decimal degrees.
#'
#' For processing multiple polygons, use \code{\link{calculate_geometric_attributes}}
#' (sequential) or \code{\link{calculate_geometric_attributes_parallel}} (parallel).
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
  v <- terra::project(v, "EPSG:4326") # Ensure geographic CRS for geodesic calculations

  # Define all available metrics
  available_metrics <- c(
    "area",
    "perimeter",
    "compactness",
    "reock",
    "elongation_rectangle",
    "num_holes",
    "hole_area",
    "hole_area_pct",
    "num_polygons",
    "ew_length",
    "ns_length",
    "maxlength",
    "bearing",
    "northerness",
    "fractaldimension",
    "sinuosity",
    "shape_index",
    "circularity_ratio",
    "decimallongitude",
    "decimallatitude"
  )

  # Validate and normalize metrics parameter
  if (is.character(metrics)) {
    if (metrics[1] == "all") {
      metrics_to_calc <- available_metrics
    } else {
      # Check that all requested metrics are valid
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
  } else {
    stop("'metrics' must be a character string or vector")
  }

  # Intermediate objects (only compute what's needed)
  need_hull <- any(
    c(
      "maxlength",
      "bearing",
      "northerness",
      "sinuosity",
      "circularity_ratio"
    ) %in%
      metrics_to_calc
  )
  need_centroid <- any(
    c("decimallongitude", "decimallatitude") %in% metrics_to_calc
  )
  need_mincircle <- "reock" %in% metrics_to_calc
  need_inh <- any(
    c("num_holes", "hole_area", "hole_area_pct") %in% metrics_to_calc
  )
  need_pols <- "num_polygons" %in% metrics_to_calc
  need_extent <- any(c("ew_length", "ns_length") %in% metrics_to_calc)
  need_area <- any(
    c(
      "area",
      "hole_area_pct",
      "compactness",
      "reock",
      "fractaldimension",
      "sinuosity",
      "shape_index"
    ) %in%
      metrics_to_calc
  )
  need_perimeter <- any(
    c(
      "perimeter",
      "compactness",
      "fractaldimension",
      "sinuosity",
      "shape_index"
    ) %in%
      metrics_to_calc
  )

  if (need_hull) {
    hull <- terra::hull(v, type = "convex")
    distant_pts <- get_distant_points(v)
  }
  if (need_centroid) {
    centroid <- terra::centroids(v)
  }
  if (need_mincircle) {
    mincircle <- terra::hull(v, type = "circle")
  }
  if (need_inh) {
    inh <- terra::fillHoles(v, inverse = TRUE)
  }
  if (need_pols) {
    pols <- terra::disagg(v)
  }

  # Basic geometric metrics
  if (need_area) {
    v$area <- terra::expanse(v, unit = "m", transform = TRUE) # Total area in square meters (geodesic)
  }
  if (need_perimeter) {
    v$perimeter <- terra::perim(v) # Total perimeter length in meters
  }

  # Compactness and shape metrics
  if ("compactness" %in% metrics_to_calc) {
    v$compactness <- (4 * pi * v$area) / (v$perimeter^2) # Polsby-Popper compactness
  }
  if ("reock" %in% metrics_to_calc) {
    v$reock <- v$area / terra::expanse(mincircle, unit = "m", transform = TRUE) # Reock compactness
  }
  if ("elongation_rectangle" %in% metrics_to_calc) {
    v$elongation_rectangle <- calc_elongation(v) # Elongation ratio
  }

  # Hole metrics
  if ("num_holes" %in% metrics_to_calc) {
    v$num_holes <- length(inh) # Number of holes
  }
  if ("hole_area" %in% metrics_to_calc) {
    v$hole_area <- sum(terra::expanse(inh, unit = "m", transform = TRUE)) # Total area of holes in square meters
  }
  if ("hole_area_pct" %in% metrics_to_calc) {
    v$hole_area_pct <- (v$hole_area / v$area) * 100 # Percentage of total area occupied by holes
  }

  # Multi-part polygon count
  if ("num_polygons" %in% metrics_to_calc) {
    v$num_polygons <- length(pols) # Number of separate polygon parts
  }

  # Extent metrics
  if ("ew_length" %in% metrics_to_calc) {
    v$ew_length <- calc_extent_ew(hull) # Average east-west extent in meters
  }
  if ("ns_length" %in% metrics_to_calc) {
    v$ns_length <- calc_extent_ns(hull) # Average north-south extent in meters
  }
  if ("maxlength" %in% metrics_to_calc) {
    v$maxlength <- distant_pts$distance # Maximum distance across convex hull in meters
  }

  # Orientation metrics
  if ("bearing" %in% metrics_to_calc) {
    v$bearing <- distant_pts$bearing # Geographic bearing in degrees
  }
  if ("northerness" %in% metrics_to_calc) {
    v$northerness <- cos(pi * (v$bearing / 180)) # Northerness component
  }

  # Complexity and shape indices
  if ("fractaldimension" %in% metrics_to_calc) {
    v$fractaldimension <- 2 * (log(v$perimeter) / log(v$area)) # Fractal dimension
  }
  if ("sinuosity" %in% metrics_to_calc) {
    v$sinuosity <- v$perimeter / v$maxlength # Sinuosity
  }
  if ("shape_index" %in% metrics_to_calc) {
    v$shape_index <- v$perimeter / (2 * sqrt(pi * v$area)) # Shape index
  }
  if ("circularity_ratio" %in% metrics_to_calc) {
    v$circularity_ratio <- (4 * v$area) / (pi * v$maxlength^2) # Circularity ratio
  }

  # Centroid coordinates
  if ("decimallongitude" %in% metrics_to_calc) {
    v$decimallongitude <- terra::crds(centroid)[, 1] # Centroid longitude
  }
  if ("decimallatitude" %in% metrics_to_calc) {
    v$decimallatitude <- terra::crds(centroid)[, 2] # Centroid latitude
  }

  # Restore original CRS
  v <- terra::project(v, verbatimCRS)

  return(v)
}
