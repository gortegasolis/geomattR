#' Calculate Elongation Ratio from Minimum Bounding Rectangle
#'
#' Calculates the elongation ratio of a polygon based on its minimum bounding
#' rectangle. The minimum bounding rectangle is computed from the convex hull of
#' the input polygon.
#'
#' @details
#' In the current implementation, elongation is computed as the ratio of the mean 
#' of the two largest side lengths to the mean of the two shortest side lengths:
#' \eqn{E = \frac{\text{mean}(\text{long sides})}{\text{mean}(\text{short sides})}}
#'
#' This approximation assumes the minimum bounding rectangle is unique,
#' which may not always be the case. Consider this with caution.
#'
#' @references
#' Dražić, Slobodan, Nebojša Ralević, and Joviša Žunić. Shape Elongation from Optimal Encasing Rectangles. \emph{Computers & Mathematics with Applications 60, no. 7 (2010): 2035–42}. \url{https://doi.org/10.1016/j.camwa.2010.07.043}.
#' 
#' @param v A SpatVector object representing a polygon, or a pre-computed convex hull if \code{isHull = TRUE}.
#' @param isHull Logical. If \code{TRUE}, \code{v} is treated as a pre-computed convex hull.
#'   If \code{FALSE} (default), the convex hull is computed internally.
#' @param output Character string. Either \code{"value"} (default) to return
#'   the elongation ratio, or \code{"polygon"} to return the input geometry
#'   with \code{elongation_rectangle} added as an attribute.
#' @param method Character string passed to \code{terra::distance()}.
#'   Defaults to \code{"geo"} (recommended). Other supported options are
#'   \code{"haversine"} and \code{"cosine"}. See \code{\link[terra]{distance}}
#'   for more information.
#' @param by_feature Logical. If \code{FALSE} (default), compute a single
#'   response from the convex hull of the whole input set. If \code{TRUE},
#'   compute one response per polygon feature.
#'
#' @return If \code{output = "value"}, a numeric value representing the
#'   elongation ratio of the input polygon from the current
#'   minimum-bounding-rectangle approximation. If
#'   \code{output = "polygon"}, the input geometry with
#'   \code{elongation_rectangle} added. When \code{by_feature = TRUE}, value
#'   output is returned as a numeric vector (one value per feature). Higher
#'   values indicate more elongated shapes.
#'
#' @export
#'
#' @examples
#' library(terra)
#' coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
#' polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")
#' elongation <- calc_elongation(polygon)
#'
#' # Using a pre-computed convex hull
#' hull_geom <- terra::hull(polygon, type = "convex")
#' elongation_hull <- calc_elongation(hull_geom, isHull = TRUE)
calc_elongation <- function(v, isHull = FALSE, output = "value", method = "geo", by_feature = FALSE) {

  if (!is.character(output) || length(output) != 1L) {
    cli::cli_abort("{.arg output} must be a single character value.", call = rlang::caller_env())
  }

  output <- match.arg(output, choices = c("value", "polygon"))

  if (!is.logical(by_feature) || length(by_feature) != 1L) {
    cli::cli_abort("{.arg by_feature} must be a single logical value.", call = rlang::caller_env())
  }

  if (by_feature) {
    prep_all <- .prepare_metric_input(v = v, isHull = isHull, method = method)
    n <- nrow(prep_all$v)
    per_values <- vapply(seq_len(n), function(i) {
      calc_elongation(
        v = prep_all$v[i, ],
        isHull = isHull,
        output = "value",
        method = method,
        by_feature = FALSE
      )
    }, numeric(1))

    if (identical(output, "value")) {
      return(per_values)
    }

    out_v <- prep_all$v
    out_v$elongation_rectangle <- per_values
    if (prep_all$isSf) {
      if (!requireNamespace("sf", quietly = TRUE)) {
        cli::cli_abort("Input is an {.pkg sf} object but the {.pkg sf} package is not installed.", call = rlang::caller_env())
      }
      out_v <- sf::st_as_sf(out_v)
    }
    return(out_v)
  }

  prep <- .prepare_metric_input(v = v, isHull = isHull, method = method)
  hull <- prep$hull

  minRectangle <- terra::hull(hull, type = "rectangle")
  dims_rect <- terra::crds(minRectangle)
  dims_rect <- terra::vect(dims_rect, crs = terra::crs(hull))

  dists_rect <- terra::distance(dims_rect, method = method)
  dists_rect <- sort(dists_rect, decreasing = TRUE)
  major <- mean(dists_rect[4:5])
  dists_rect <- sort(dists_rect, decreasing = FALSE)
  minor <- mean(dists_rect[2:3])

  value <- c(elongation_rectangle = major / minor)

  .return_metric_output(
    v = prep$v,
    isSf = prep$isSf,
    output = output,
    values = value
  )
}
