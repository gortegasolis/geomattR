#' Calculate Elongation Ratio from Minimum Bounding Rectangle
#'
#' Calculates the elongation ratio of a polygon based on its minimum bounding
#' rectangle. The ratio is the major axis length divided by the minor axis length.
#' The minimum bounding rectangle is computed from the convex hull of the input polygon.
#' It is important to notice that this method assumes the minimum bounding rectangle is unique, 
#' which may not always be the case. Consider this with caution.
#'
#' @param v A SpatVector object representing a polygon.
#' @param hull An optional pre-computed convex hull (SpatVector). If \code{NULL}
#'   (default), the convex hull is computed internally. Passing a pre-computed
#'   hull avoids redundant computation.
#'
#' @return A numeric value representing the elongation ratio (major/minor axis) of the input polygon.
#'   Higher values indicate more elongated shapes.
#'
#' @export
#'
#' @examples
#' library(terra)
#' coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
#' polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")
#' elongation <- calc_elongation(polygon)
calc_elongation <- function(v, hull = NULL) {
  if (is.null(hull)) {
    hull <- terra::hull(v, type = "convex")
  }

  minRectangle <- terra::hull(hull, type = "rectangle")
  dims_rect <- terra::crds(minRectangle)
  dims_rect <- terra::vect(dims_rect, crs = terra::crs(v))

  dists_rect <- terra::distance(dims_rect, method = "geo")
  dists_rect <- sort(dists_rect, decreasing = TRUE)
  major <- mean(dists_rect[1:2])
  dists_rect <- sort(dists_rect, decreasing = FALSE)
  minor <- mean(dists_rect[1:2])

  major / minor
}
