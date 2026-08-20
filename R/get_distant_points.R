#' Find largest distance between a pair of opposite vertices
#'
#' Identifies the pair of most distant points on a polygon's convex hull and
#' calculates their distance (using the selected \code{method}) and the bearing
#' from the southernmost to the northernmost point.
#'
#' @details
#' Distances between \strong{all} convex-hull vertex pairs are evaluated with
#' \code{terra::distance()} using the selected \code{method}, so the returned
#' pair is the true geodesic maximum (hulls are small, so the exhaustive
#' search is cheap). An earlier rotating-calipers implementation searched
#' antipodal pairs in planar coordinate space, which could miss the geodesic
#' maximum on lon/lat data.
#'
#' \strong{Tie-breaking & Point Ordering:}
#' If multiple antipodal pairs share the maximum distance, ties are broken by selecting the
#' pair containing the southernmost (and then westernmost) coordinate. The points are ordered
#' in the output such that:
#' \itemize{
#'   \item \code{south_point} (point 1): the southernmost (and westernmost, in case of a tie) point of the pair.
#'   \item \code{north_point} (point 2): the northernmost (and easternmost) point of the pair.
#' }
#' The geographic bearing is calculated from \code{south_point} to \code{north_point}
#' using \code{geosphere::bearing()}. When needed, the geometry is internally
#' transformed to geographic coordinates for bearing calculation.
#'
#' @param v A SpatVector object representing a polygon, or a pre-computed convex hull if \code{isHull = TRUE}.
#' @param isHull Logical. If \code{TRUE}, \code{v} is treated as a pre-computed convex hull.
#'   If \code{FALSE} (default), the convex hull is computed internally.
#' @param distance Logical indicating whether to return the maximum distance
#'   (default \code{TRUE}).
#' @param bearing Logical indicating whether to return the bearing (default
#'   \code{TRUE}).
#' @param output Character string. \code{"points"} (default) returns point
#'   geometry outputs. \code{"value"} returns numeric metric values only,
#'   and \code{"polygon"} returns the input geometry with requested metric
#'   columns added.
#' @param method Character string passed to \code{terra::distance()}.
#'   Defaults to \code{"geo"} (recommended). Other supported options are
#'   \code{"haversine"} and \code{"cosine"}. All three are lon/lat great-circle
#'   methods; on a projected CRS, \code{method} is ignored and distances are
#'   Cartesian. Bearing is computed from geographic coordinates when needed.
#' @param by_feature Logical. If \code{FALSE} (default), compute a single
#'   response from the convex hull of the whole input set. If \code{TRUE},
#'   compute one response per polygon feature.
#'
#' @return For \code{output = "points"}, a list containing:
#'   \item{south_point}{SpatVector of the southernmost point}
#'   \item{north_point}{SpatVector of the northernmost point}
#'   \item{distance}{Maximum distance in meters (if \code{distance = TRUE})}
#'   \item{bearing}{Axial orientation: geographic bearing from the southernmost
#'     to the northernmost point, in degrees within \[-90, 90\] (if
#'     \code{bearing = TRUE}). Because the pair is always ordered south to
#'     north, this describes the orientation of the longest axis, not a travel
#'     direction: -90/90 is east-west, 0 is north-south.}
#' For \code{output = "value"}, returns a numeric scalar when one metric is
#' requested, or a named numeric vector when both are requested.
#' For \code{output = "polygon"}, returns the input geometry with the
#' requested metric columns added.
#' When \code{by_feature = TRUE}, returns per-feature outputs (list,
#' numeric vector/data.frame, or polygon with columns, depending on
#' \code{output}).
#'
#' @export
#'
#' @examples
#' library(terra)
#' coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
#' polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")
#' distant_pts <- get_distant_points(polygon)
#'
#' # Using a pre-computed convex hull
#' hull_geom <- terra::hull(polygon, type = "convex")
#' distant_pts_hull <- get_distant_points(hull_geom, isHull = TRUE)
get_distant_points <- function(v, isHull = FALSE, distance = TRUE, bearing = TRUE, output = "points", by_feature = FALSE, method = "geo") {
  output <- match.arg(output, choices = c("points", "value", "polygon"))

  if (!is.logical(by_feature) || length(by_feature) != 1L) {
    cli::cli_abort("{.arg by_feature} must be a single logical value.", call = rlang::caller_env())
  }
  if (!is.logical(distance) || length(distance) != 1L) {
    cli::cli_abort("{.arg distance} must be a single logical value.", call = rlang::caller_env())
  }
  if (!is.logical(bearing) || length(bearing) != 1L) {
    cli::cli_abort("{.arg bearing} must be a single logical value.", call = rlang::caller_env())
  }
  if (!distance && !bearing) {
    cli::cli_abort("At least one of {.arg distance} or {.arg bearing} must be TRUE.", call = rlang::caller_env())
  }

  prep_method <- if (bearing) "geo" else method

  if (by_feature) {
    prep_all <- .prepare_metric_input(v = v, isHull = isHull, method = prep_method, build_hull = FALSE)
    n <- nrow(prep_all$v)
    per_out <- lapply(seq_len(n), function(i) {
      get_distant_points(
        v = prep_all$v[i, ],
        isHull = isHull,
        distance = distance,
        bearing = bearing,
        output = output,
        by_feature = FALSE,
        method = method
      )
    })

    if (output == "points") {
      return(per_out)
    }

    if (output == "value") {
      if (distance && !bearing) {
        return(as.numeric(unlist(per_out, use.names = FALSE)))
      }
      if (!distance && bearing) {
        return(as.numeric(unlist(per_out, use.names = FALSE)))
      }

      out_df <- as.data.frame(do.call(rbind, per_out))
      rownames(out_df) <- NULL
      return(out_df)
    }

    out_v <- prep_all$v
    if (distance) {
      out_v$distance <- vapply(per_out, function(x) as.numeric(x$distance), numeric(1))
    }
    if (bearing) {
      out_v$bearing <- vapply(per_out, function(x) as.numeric(x$bearing), numeric(1))
    }
    if (prep_all$isSf) {
      if (!requireNamespace("sf", quietly = TRUE)) {
        cli::cli_abort("Input is an {.pkg sf} object but the {.pkg sf} package is not installed.", call = rlang::caller_env())
      }
      out_v <- sf::st_as_sf(out_v)
    }
    return(out_v)
  }

  prep <- .prepare_metric_input(v = v, isHull = isHull, method = prep_method)
  hull <- prep$hull

  coords <- .normalize_hull_coords(terra::crds(hull))
  n <- nrow(coords)
  points_hull <- terra::vect(coords, crs = terra::crs(hull))

  if (n == 1L) {
    subset_hull <- points_hull[c(1, 1), ]
  } else {
    # Evaluate all hull-vertex pairs geodesically in a single vectorised call;
    # planar antipodal-pair candidates can miss the geodesic maximum.
    candidate_pairs <- which(upper.tri(matrix(0, n, n)), arr.ind = TRUE)

    dists <- as.numeric(terra::distance(
      points_hull[candidate_pairs[, 1], ],
      points_hull[candidate_pairs[, 2], ],
      method = method,
      pairwise = TRUE
    ))

    # Among the (near-)maximal pairs, select the one whose southern endpoint
    # is southernmost (then westernmost).
    tied <- which(dists >= max(dists) - 1e-9)
    best_pair <- candidate_pairs[tied[1], ]
    best_south <- c(Inf, Inf)
    for (i in tied) {
      pair <- candidate_pairs[i, ]
      pair_coords <- coords[pair, , drop = FALSE]
      order_idx <- order(pair_coords[, 2], pair_coords[, 1])
      south_coords <- pair_coords[order_idx[1], ]

      if (south_coords[2] < best_south[2] - 1e-12 ||
        (abs(south_coords[2] - best_south[2]) <= 1e-12 &&
          south_coords[1] < best_south[1] - 1e-12)) {
        best_pair <- pair
        best_south <- south_coords
      }
    }

    subset_hull <- points_hull[best_pair, ]
  }

  coords_subset <- terra::crds(subset_hull)
  order_idx <- order(coords_subset[, 2], coords_subset[, 1])
  south_point <- subset_hull[order_idx[1], ]
  north_point <- subset_hull[order_idx[2], ]

  result <- list(
    south_point = south_point,
    north_point = north_point
  )

  if (distance) {
    result$distance <- terra::distance(south_point, north_point, method = method)
  }

  if (bearing) {
    result$bearing <- geosphere::bearing(
      terra::crds(south_point),
      terra::crds(north_point)
    )
  }

  if (output == "points") {
    return(result)
  }

  values <- c()
  if (distance) {
    values <- c(values, distance = as.numeric(result$distance))
  }
  if (bearing) {
    values <- c(values, bearing = as.numeric(result$bearing))
  }

  .return_metric_output(
    v = prep$v,
    isSf = prep$isSf,
    output = output,
    values = values
  )
}
