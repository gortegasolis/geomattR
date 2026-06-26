#' Find largest distance between a pair of opposite vertices
#'
#' Identifies the pair of most distant points on a polygon's convex hull and
#' calculates the geodesic distance and bearing from the southernmost to the
#' northernmost point.
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
#' @param by_feature Logical. If \code{FALSE} (default), compute a single
#'   response from the convex hull of the whole input set. If \code{TRUE},
#'   compute one response per polygon feature.
#'
#' @return For \code{output = "points"}, a list containing:
#'   \item{south_point}{SpatVector of the southernmost point}
#'   \item{north_point}{SpatVector of the northernmost point}
#'   \item{distance}{Maximum distance in meters (if \code{distance = TRUE})}
#'   \item{bearing}{Geographic bearing from south to north in degrees (if
#'     \code{bearing = TRUE})}
#' For \code{output = "value"}, returns a numeric scalar when one metric is
#' requested, or a named numeric vector when both are requested.
#' For \code{output = "polygon"}, returns the input geometry with the
#' requested metric columns added.
#' When \code{by_feature = TRUE}, returns per-feature outputs (list,
#' numeric vector/data.frame, or polygon with columns, depending on
#' \code{output}).
#'
#' @details
#' The most distant hull-vertex pair is found with rotating calipers over the
#' convex hull (linear in the number of hull vertices), then geodesic distances
#' are evaluated only for candidate antipodal pairs.
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
get_distant_points <- function(v, isHull = FALSE, distance = TRUE, bearing = TRUE, output = "points", by_feature = FALSE) {
  output <- match.arg(output, choices = c("points", "value", "polygon"))

  if (!is.logical(by_feature) || length(by_feature) != 1L) {
    stop("'by_feature' must be a single logical value.")
  }
  if (!is.logical(distance) || length(distance) != 1L) {
    stop("'distance' must be a single logical value.")
  }
  if (!is.logical(bearing) || length(bearing) != 1L) {
    stop("'bearing' must be a single logical value.")
  }
  if (!distance && !bearing) {
    stop("At least one of 'distance' or 'bearing' must be TRUE.")
  }

  if (by_feature) {
    prep_all <- .prepare_metric_input(v = v, isHull = isHull, method = "geo")
    n <- nrow(prep_all$v)
    per_out <- lapply(seq_len(n), function(i) {
      get_distant_points(
        v = prep_all$v[i, ],
        isHull = isHull,
        distance = distance,
        bearing = bearing,
        output = output,
        by_feature = FALSE
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
        stop("Input is an 'sf' object but the 'sf' package is not installed.")
      }
      out_v <- sf::st_as_sf(out_v)
    }
    return(out_v)
  }

  prep <- .prepare_metric_input(v = v, isHull = isHull, method = "geo")
  hull <- prep$hull
  
  coords <- .normalize_hull_coords(terra::crds(hull))
  n <- nrow(coords)
  points_hull <- terra::vect(coords, crs = terra::crs(hull))

  if (n == 1L) {
    subset_hull <- points_hull[c(1, 1), ]
  } else {
    candidate_pairs <- .find_antipodal_pairs(coords)

    best_dist <- -Inf
    best_pair <- candidate_pairs[1, ]
    best_south <- c(Inf, Inf)

    for (i in seq_len(nrow(candidate_pairs))) {
      pair <- candidate_pairs[i, ]
      p1 <- points_hull[pair[1], ]
      p2 <- points_hull[pair[2], ]
      d <- terra::distance(p1, p2, method = "geo")

      pair_coords <- coords[pair, , drop = FALSE]
      order_idx <- order(pair_coords[, 2], pair_coords[, 1])
      south_coords <- pair_coords[order_idx[1], ]

      better <- FALSE
      if (d > best_dist + 1e-9) {
        better <- TRUE
      } else if (abs(d - best_dist) <= 1e-9) {
        if (south_coords[2] < best_south[2] - 1e-12 ||
          (abs(south_coords[2] - best_south[2]) <= 1e-12 &&
            south_coords[1] < best_south[1] - 1e-12)) {
          better <- TRUE
        }
      }

      if (better) {
        best_dist <- d
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
    result$distance <- terra::distance(south_point, north_point, method = "geo")
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
