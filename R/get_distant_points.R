#' Find largest distance between a pair of opposite vertices
#'
#' Identifies the pair of most distant points on a polygon's convex hull and
#' calculates the geodesic distance and bearing from the southernmost to the
#' northernmost point.
#'
#' @param v A SpatVector object representing a polygon.
#' @param hull An optional pre-computed convex hull (SpatVector). If \code{NULL}
#'   (default), the convex hull is computed internally. Passing a pre-computed
#'   hull avoids redundant computation when calling from higher-level functions.
#' @param distance Logical indicating whether to return the maximum distance
#'   (default \code{TRUE}).
#' @param bearing Logical indicating whether to return the bearing (default
#'   \code{TRUE}).
#'
#' @return A list containing:
#'   \item{south_point}{SpatVector of the southernmost point}
#'   \item{north_point}{SpatVector of the northernmost point}
#'   \item{distance}{Maximum distance in meters (if \code{distance = TRUE})}
#'   \item{bearing}{Geographic bearing from south to north in degrees (if
#'     \code{bearing = TRUE})}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#' polygon <- vect("path/to/polygon.shp")
#' distant_pts <- get_distant_points(polygon)
#' }
get_distant_points <- function(v, hull = NULL, distance = TRUE, bearing = TRUE) {
  if (is.null(hull)) {
    hull <- terra::hull(v, type = "convex")
  }
  coords <- terra::crds(hull)

  # Find the pair of most distant points
  points_hull <- terra::vect(coords, crs = terra::crs(v))
  dists_hull <- terra::distance(points_hull, method = "geo")
  dists_hull <- as.matrix(dists_hull)
  max_dist_idx <- which(dists_hull == max(dists_hull), arr.ind = TRUE)[1, ]
  start_idx <- max_dist_idx[1]
  end_idx <- max_dist_idx[2]
  subset_hull <- points_hull[c(start_idx, end_idx), ]

  # Ensure south_point is the southernmost point

  coords_subset <- terra::crds(subset_hull)
  order_idx <- order(coords_subset[, 2])
  south_point <- subset_hull[order_idx[1], ]
  north_point <- subset_hull[order_idx[2], ]

  result <- list(
    south_point = south_point,
    north_point = north_point
  )

  if (distance) {
    result$distance <- terra::distance(south_point, north_point, method = "geo")
  }

  if (bearing) {
    result$bearing <- geosphere::bearing(
      terra::crds(south_point),
      terra::crds(north_point)
    )
  }

  return(result)
}
