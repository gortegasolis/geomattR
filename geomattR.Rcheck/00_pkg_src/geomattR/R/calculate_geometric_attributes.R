#' Calculate Geometric Attributes of Spatial Polygons
#'
#' Calculates a comprehensive set of geometric and morphometric attributes for
#' spatial polygon features including area, perimeter, compactness metrics,
#' shape indices, elongation, and orientation measures. If multiple features are
#' provided, processes each feature sequentially.
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
#' The function calculates various geometric metrics that describe polygon shape,
#' size, and orientation. For multiple features, each polygon is processed
#' sequentially. For parallel processing, use
#' \code{\link{calculate_geometric_attributes_parallel}}.
#'
#' \strong{Size metrics:}
#' - Area and perimeter provide basic size measurements
#' - Extents (EW, NS, maxlength) measure spatial dimensions
#'
#' \strong{Shape metrics:}
#' - Compactness measures how closely a polygon resembles a circle
#' - Shape index and circularity provide alternative shape characterizations
#' - Fractal dimension measures boundary complexity
#'
#' \strong{Orientation metrics:}
#' - Bearing and northerness describe polygon orientation
#' - Elongation quantifies directional stretching
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#' 
#' # Load a polygon shapefile (single or multiple features)
#' polygons <- vect("path/to/polygons.shp")
#' 
#' # Calculate all geometric attributes (processes sequentially)
#' polygons_with_attrs <- calculate_geometric_attributes(polygons)
#' 
#' # Calculate specific metrics only
#' polygons_subset <- calculate_geometric_attributes(polygons, 
#'                      metrics = c("area", "perimeter", "compactness"))
#' 
#' # View the results
#' print(polygons_with_attrs)
#' }
calculate_geometric_attributes <- function(v, metrics = "all") {
  # Validate input
  if (!methods::is(v, "SpatVector")) {
    stop("'v' must be a SpatVector object")
  }
  
  n_features <- nrow(v)
  
  # If multiple features, process each one and combine results
  if (n_features > 1) {
    results <- lapply(1:n_features, function(i) {
      calculate_geometric_attributes_single(v[i, ], metrics = metrics)
    })
    return(do.call(rbind, results))
  }
  
  # Single feature: process directly
  return(calculate_geometric_attributes_single(v, metrics = metrics))
}
