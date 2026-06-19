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
#' @details
#' The most distant hull-vertex pair is found with rotating calipers over the
#' convex hull (linear in the number of hull vertices), then geodesic distances
#' are evaluated only for candidate antipodal pairs.
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
  coords <- normalize_hull_coords(terra::crds(hull))
  n <- nrow(coords)
  points_hull <- terra::vect(coords, crs = terra::crs(v))

  if (n == 1L) {
    subset_hull <- points_hull[c(1, 1), ]
  } else {
    candidate_pairs <- find_antipodal_pairs(coords)

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

  return(result)
}

normalize_hull_coords <- function(coords) {
  xy <- as.matrix(coords[, 1:2, drop = FALSE])
  xy <- xy[stats::complete.cases(xy), , drop = FALSE]

  if (nrow(xy) == 0L) {
    stop("Hull has no valid coordinates")
  }

  if (nrow(xy) > 1L) {
    keep <- c(
      TRUE,
      rowSums(abs(xy[-1, , drop = FALSE] - xy[-nrow(xy), , drop = FALSE])) > 0
    )
    xy <- xy[keep, , drop = FALSE]
  }

  if (nrow(xy) > 1L && all(abs(xy[1, ] - xy[nrow(xy), ]) == 0)) {
    xy <- xy[-nrow(xy), , drop = FALSE]
  }

  if (nrow(xy) >= 3L) {
    x <- xy[, 1]
    y <- xy[, 2]
    x_next <- c(x[-1], x[1])
    y_next <- c(y[-1], y[1])
    signed_area2 <- sum(x * y_next - x_next * y)
    if (signed_area2 < 0) {
      xy <- xy[rev(seq_len(nrow(xy))), , drop = FALSE]
    }
  }

  xy
}

find_antipodal_pairs <- function(coords, tol = 1e-12) {
  n <- nrow(coords)
  if (n <= 1L) {
    return(matrix(c(1L, 1L), ncol = 2))
  }
  if (n == 2L) {
    return(matrix(c(1L, 2L), ncol = 2))
  }

  idx <- function(k) ((k - 1L) %% n) + 1L
  tri_area2 <- function(i, j, k) {
    a <- coords[i, ]
    b <- coords[j, ]
    c <- coords[k, ]
    abs((b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]))
  }

  j <- 2L
  while (tri_area2(n, 1L, idx(j + 1L)) > tri_area2(n, 1L, j) + tol) {
    j <- idx(j + 1L)
  }

  pairs <- matrix(numeric(0), ncol = 2)
  for (i in seq_len(n)) {
    i_next <- idx(i + 1L)
    pairs <- rbind(pairs, c(i, j))

    repeat {
      j_next <- idx(j + 1L)
      area_current <- tri_area2(i, i_next, j)
      area_next <- tri_area2(i, i_next, j_next)

      if (area_next > area_current + tol) {
        j <- j_next
        pairs <- rbind(pairs, c(i, j))
      } else {
        if (abs(area_next - area_current) <= tol) {
          pairs <- rbind(pairs, c(i, j_next))
        }
        break
      }
    }
  }

  if (nrow(pairs) == 0L) {
    return(matrix(c(1L, 2L), ncol = 2))
  }

  pairs <- t(apply(pairs, 1, function(p) sort(as.integer(p))))
  unique(pairs)
}
