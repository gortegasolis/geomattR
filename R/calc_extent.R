#' Calculate East-West Extent
#'
#' Calculates the average east-west extent of a polygon based on its geographic bounding box.
#'
#' @param v A SpatVector object representing a polygon.
#'
#' @return A numeric value representing the average east-west extent in meters.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#' polygon <- vect("path/to/polygon.shp")
#' ew_extent <- calc_extent_ew(polygon)
#' }
calc_extent_ew <- function(v) {
  b <- terra::ext(v)
  pt1 <- terra::vect(cbind(b$xmin, b$ymin), crs = terra::crs(v))
  pt2 <- terra::vect(cbind(b$xmax, b$ymin), crs = terra::crs(v))
  pt3 <- terra::vect(cbind(b$xmin, b$ymax), crs = terra::crs(v))
  pt4 <- terra::vect(cbind(b$xmax, b$ymax), crs = terra::crs(v))
  
  dist1 <- terra::distance(pt1, pt2, method = "geo")
  dist2 <- terra::distance(pt3, pt4, method = "geo")

  mean(c(dist1, dist2))
}

#' Calculate North-South Extent
#'
#' Calculates the average north-south extent of a polygon based on its geographic bounding box.
#'
#' @param v A SpatVector object representing a polygon.
#'
#' @return A numeric value representing the average north-south extent in meters.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#' polygon <- vect("path/to/polygon.shp")
#' ns_extent <- calc_extent_ns(polygon)
#' }
calc_extent_ns <- function(v) {
  b <- terra::ext(v)
  pt1 <- terra::vect(cbind(b$xmin, b$ymin), crs = terra::crs(v))
  pt2 <- terra::vect(cbind(b$xmax, b$ymin), crs = terra::crs(v))
  pt3 <- terra::vect(cbind(b$xmin, b$ymax), crs = terra::crs(v))
  pt4 <- terra::vect(cbind(b$xmax, b$ymax), crs = terra::crs(v))
  
  dist1 <- terra::distance(pt1, pt3, method = "geo")
  dist2 <- terra::distance(pt2, pt4, method = "geo")

  mean(c(dist1, dist2))
}
