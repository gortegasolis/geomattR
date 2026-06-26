#' Calculate Polygon Extent
#'
#' Calculates east-west and/or north-south extent of a polygon based on its
#' geographic bounding box.
#'
#' @param v A SpatVector object representing a polygon, or a pre-computed convex
#'   hull if \code{isHull = TRUE}.
#' @param isHull Logical. If \code{TRUE}, \code{v} is treated as a pre-computed
#'   convex hull. If \code{FALSE} (default), the convex hull is computed
#'   internally.
#' @param direction Character vector indicating which extent(s) to return when
#'   \code{output = "value"} or \code{output = "polygon"}. Valid values are
#'   \code{"ew"} and \code{"ns"}. Default is both.
#' @param output Character string. Either \code{"value"} (default) to return
#'   extent values, or \code{"polygon"} to return the input geometry with the
#'   requested extent columns added.
#' @param method Character string passed to \code{terra::distance()}.
#'   Defaults to \code{"geo"}.
#' @param by_feature Logical. If \code{FALSE} (default), compute a single
#'   response from the convex hull of the whole input set. If \code{TRUE},
#'   compute one response per polygon feature.
#'
#' @return If \code{output = "value"} and one direction is requested, returns a
#'   numeric scalar. If both directions are requested, returns a named numeric
#'   vector with \code{ew_length} and \code{ns_length}. If
#'   \code{output = "polygon"}, returns the input geometry with the requested
#'   extent columns added. When \code{by_feature = TRUE}, value output is
#'   returned per feature (numeric vector for one direction, data.frame for both
#'   directions).
#'
#' @details
#' Extent is computed from the convex hull bounding box corners using
#' \code{terra::distance()} with the selected \code{method}.
#' When \code{method} is \code{"geo"} or \code{"haversine"}, the hull is
#' projected to EPSG:4326 when needed before distance calculations.
#'
#' For \code{output = "value"}:
#' \itemize{
#'   \item \code{direction = "ew"}: returns east-west extent (numeric scalar)
#'   \item \code{direction = "ns"}: returns north-south extent (numeric scalar)
#'   \item \code{direction = c("ew", "ns")} (any order): returns both values as
#'     a named numeric vector
#' }
#'
#' For \code{output = "polygon"}, only the requested extent columns are added
#' as attributes.
#'
#' @export
#'
#' @examples
#' library(terra)
#' coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
#' polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")
#'
#' # Get one extent value
#' ew_extent <- calc_extent(polygon, direction = "ew")
#'
#' # Get both extent values
#' both_extents <- calc_extent(polygon, direction = c("ns", "ew"))
#'
#' # Return polygon with only requested extent columns
#' polygon_with_ew <- calc_extent(polygon, direction = "ew", output = "polygon")
#'
#' # Return polygon with both extent columns
#' polygon_with_extents <- calc_extent(polygon, output = "polygon")
#'
#' # Use a custom distance method supported by terra::distance()
#' extents_planar <- calc_extent(polygon, direction = c("ew", "ns"), method = "cosine")
calc_extent <- function(v, isHull = FALSE, direction = c("ew", "ns"), output = "value", method = "geo", by_feature = FALSE) {
  direction <- unique(direction)
  if (!is.character(direction) || length(direction) < 1L) {
    stop("'direction' must be a character vector with 'ew' and/or 'ns'.")
  }
  if (!all(direction %in% c("ew", "ns"))) {
    stop("Invalid direction. Use 'ew', 'ns', or c('ew', 'ns').")
  }
  if (!is.logical(by_feature) || length(by_feature) != 1L) {
    stop("'by_feature' must be a single logical value.")
  }

  if (by_feature) {
    prep_all <- .prepare_metric_input(v = v, isHull = isHull, method = method)
    n <- nrow(prep_all$v)
    per_values <- lapply(seq_len(n), function(i) {
      calc_extent(
        v = prep_all$v[i, ],
        isHull = isHull,
        direction = direction,
        output = "value",
        method = method,
        by_feature = FALSE
      )
    })

    if (identical(output, "value")) {
      if (length(direction) == 1L) {
        return(as.numeric(unlist(per_values, use.names = FALSE)))
      }

      out_df <- as.data.frame(do.call(rbind, per_values))
      rownames(out_df) <- NULL
      return(out_df)
    }

    out_v <- prep_all$v
    if ("ew" %in% direction) {
      out_v$ew_length <- vapply(per_values, function(x) as.numeric(x[["ew_length"]]), numeric(1))
    }
    if ("ns" %in% direction) {
      out_v$ns_length <- vapply(per_values, function(x) as.numeric(x[["ns_length"]]), numeric(1))
    }

    if (prep_all$isSf) {
      if (!requireNamespace("sf", quietly = TRUE)) {
        stop("Input is an 'sf' object but the 'sf' package is not installed.")
      }
      out_v <- sf::st_as_sf(out_v)
    }

    return(out_v)
  }

  prep <- .prepare_metric_input(v = v, isHull = isHull, method = method)
  values <- .calc_extent_values(prep$hull, direction = direction, method = method)
  values <- values[paste0(direction, "_length")]

  .return_metric_output(
    v = prep$v,
    isSf = prep$isSf,
    output = output,
    values = values
  )
}
