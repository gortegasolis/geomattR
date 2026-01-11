#' Find largest distance between a pair of opposite vertices
#'
#' Identifies the pair of most distant points and calculate the distance and bearing from the southernmost to the northernmost point.
#'
#' @param v A SpatVector object representing a polygon.
#' @param distance Logical indicating whether to return the maximum distance (default TRUE).
#' @param bearing Logical indicating whether to return the bearing (default TRUE).
#'
#' @return A list containing:
#'   \item{south_point}{SpatVector of the southernmost point}
#'   \item{north_point}{SpatVector of the northernmost point}
#'   \item{distance}{Maximum distance in meters}
#'   \item{bearing}{Geographic bearing from south to north in degrees}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#' polygon <- vect("path/to/polygon.shp")
#' distant_pts <- get_distant_points(polygon)
#' }
get_distant_points <- function(v, distance = TRUE, bearing = TRUE) {
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
  order_idx <- order(coords_subset[, 2]) # Order by latitude (y coordinate)
  south_point <- subset_hull[order_idx[1], ] # Point with minimum latitude
  north_point <- subset_hull[order_idx[2], ] # Point with maximum latitude

  result <- list(
    south_point = south_point,
    north_point = north_point
  )

  if (distance) {
    max_dist <- terra::distance(south_point, north_point, method = "geo")
    result$distance <- max_dist
  }

  if (bearing) {
    bearing_val <- geosphere::bearing(south_point, north_point)
    result$bearing <- bearing_val
  }
  return(result)
}
