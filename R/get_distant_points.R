#' Find Most Distant Points on Convex Hull
#'
#' Identifies the pair of most distant points on the convex hull of a polygon,
#' ordered from south to north.
#'
#' @param v A SpatVector object representing a polygon.
#'
#' @return A list containing:
#'   \item{start_ll}{SpatVector of the southernmost point}
#'   \item{end_ll}{SpatVector of the northernmost point}
#'   \item{distance}{Maximum distance in meters}
#'   \item{bearing}{Geographic bearing from start to end in degrees}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#' polygon <- vect("path/to/polygon.shp")
#' distant_pts <- get_distant_points(polygon)
#' }
get_distant_points <- function(v) {
  hull <- terra::hull(v, type = "convex")
  coords <- terra::crds(hull)
  
  # Find the pair of most distant points
  points_hull <- terra::vect(coords, crs = terra::crs(v))
  dists_hull <- terra::distance(points_hull, method = "geo")
  dists_hull <- as.matrix(dists_hull)
  max_dist_idx <- which(dists_hull == max(dists_hull), arr.ind = TRUE)[1, ]
  start_idx <- max_dist_idx[1]
  end_idx <- max_dist_idx[2]
  subset_hull <- points_hull[c(start_idx, end_idx), ]
  
  # Ensure start_ll is the southernmost point
  coords_subset <- terra::crds(subset_hull)
  order_idx <- order(coords_subset[, 2])  # Order by latitude (y coordinate)
  start_ll <- subset_hull[order_idx[1], ]  # Point with minimum latitude
  end_ll <- subset_hull[order_idx[2], ]    # Point with maximum latitude
  
  max_dist <- terra::distance(start_ll, end_ll, method = "geo")
  bearing_val <- geosphere::bearing(start_ll, end_ll)
  
  list(
    start_ll = start_ll,
    end_ll = end_ll,
    distance = max_dist,
    bearing = bearing_val
  )
}
