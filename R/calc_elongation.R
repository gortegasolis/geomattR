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
#' The minimum bounding rectangle is a planar (GEOS) construction. For lon/lat
#' input it is computed in a local Lambert azimuthal equal-area projection
#' centred on the feature, so that the *minimum* rectangle is not distorted by
#' the varying length of a degree of longitude; the rectangle is then measured
#' back in the input's CRS with the selected \code{method}.
#'
#' This approximation assumes the minimum bounding rectangle is unique,
#' which may not always be the case. Consider this with caution.
#'
#' @references
#' Dražić, Slobodan, Nebojša Ralević, and Joviša Žunić. Shape Elongation from Optimal Encasing Rectangles. \emph{Computers & Mathematics with Applications 60, no. 7 (2010): 2035–42}. \doi{10.1016/j.camwa.2010.07.043}.
#' 
#' @param v A SpatVector object representing a polygon, or a pre-computed convex hull if \code{isHull = TRUE}.
#' @param isHull Logical. If \code{TRUE}, \code{v} is treated as a pre-computed convex hull.
#'   If \code{FALSE} (default), the convex hull is computed internally.
#' @param output Character string. Either \code{"value"} (default) to return
#'   the elongation ratio, or \code{"polygon"} to return the input geometry
#'   with \code{elongation_rectangle} added as an attribute.
#' @param method Character string passed to \code{terra::distance()}.
#'   Defaults to \code{"geo"} (recommended). Other supported options are
#'   \code{"haversine"} and \code{"cosine"}. All three are lon/lat great-circle
#'   methods; on a projected CRS, \code{method} is ignored and distances are
#'   Cartesian. See \code{\link[terra]{distance}} for more information.
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
    prep_all <- .prepare_metric_input(v = v, isHull = isHull, method = method, build_hull = FALSE)
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

  # Minimize the bounding rectangle in a local planar CRS (GEOS hulls are
  # planar; in lon/lat degrees the minimum would be distorted by latitude),
  # then measure its edges back in the hull's CRS with the selected method.
  minRectangle <- .local_hull(hull, type = "rectangle")
  rect_coords <- terra::crds(minRectangle)

  # Keep the unique corners in ring order (crds() repeats the closing vertex).
  corner_keep <- !duplicated(rect_coords, MARGIN = 1)
  rect_coords <- rect_coords[corner_keep, , drop = FALSE]

  n_corners <- nrow(rect_coords)
  if (n_corners < 3L) {
    # Degenerate rectangle (point or line): minor axis is zero.
    return(.return_metric_output(
      v = prep$v,
      isSf = prep$isSf,
      output = output,
      values = c(elongation_rectangle = Inf)
    ))
  }

  # Explicitly measure the ring edges instead of slicing sorted pairwise
  # distances.
  rect_pts <- terra::vect(rect_coords, crs = terra::crs(hull))
  next_idx <- c(2:n_corners, 1L)
  edges <- vapply(seq_len(n_corners), function(i) {
    as.numeric(terra::distance(rect_pts[i, ], rect_pts[next_idx[i], ], method = method))
  }, numeric(1))

  edges <- sort(edges, decreasing = TRUE)
  half <- length(edges) %/% 2L
  major <- mean(edges[seq_len(half)])
  minor <- mean(edges[(half + 1L):length(edges)])

  if (!is.finite(minor) || minor <= 0) {
    value <- c(elongation_rectangle = Inf)
  } else {
    value <- c(elongation_rectangle = major / minor)
  }

  .return_metric_output(
    v = prep$v,
    isSf = prep$isSf,
    output = output,
    values = value
  )
}
