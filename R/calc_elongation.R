#' Calculate Elongation Ratio from Minimum Bounding Rectangle
#'
#' Calculates the elongation ratio of a polygon based on its minimum bounding
#' rectangle. The ratio is the major axis length divided by the minor axis length.
#'
#' @param v A SpatVector object representing a polygon.
#'
#' @return A numeric value representing the elongation ratio (major/minor axis).
#'   Higher values indicate more elongated shapes.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#' polygon <- vect("path/to/polygon.shp")
#' elongation <- calc_elongation(polygon)
#' }
calc_elongation <- function(v) {
  minRectangle <- terra::hull(v, type = "rectangle")
  dims_rect <- terra::crds(minRectangle)
  dims_rect <- terra::vect(dims_rect, crs = terra::crs(v))
  
  dists_rect <- terra::distance(dims_rect, method = "geo")
  dists_rect <- sort(dists_rect, decreasing = TRUE)
  major <- mean(dists_rect[1:2])
  dists_rect <- sort(dists_rect, decreasing = FALSE)
  minor <- mean(dists_rect[1:2])
  
  major / minor
}
