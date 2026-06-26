.prepare_metric_input <- function(v, isHull = FALSE, method = "geo") {
  isSf <- inherits(v, "sf")
  if (isSf) {
    v <- terra::vect(v)
  }

  if (!methods::is(v, "SpatVector")) {
    stop("'v' must be a SpatVector object")
  }

  hull <- if (isHull) v else terra::hull(v, type = "convex")
  if (method %in% c("geo", "haversine") && !terra::is.lonlat(hull)) {
    hull <- terra::project(hull, "EPSG:4326")
  }

  list(v = v, hull = hull, isSf = isSf)
}

.return_metric_output <- function(v, isSf, output = "value", values) {
  if (length(output) != 1L) {
    stop("Output type must be a single value: either 'value' or 'polygon'.")
  }
  output <- match.arg(output, choices = c("value", "polygon"))

  if (output == "value") {
    if (length(values) == 1L) {
      return(unname(values[[1]]))
    }
    return(values)
  }

  value_names <- names(values)
  if (is.null(value_names) || any(value_names == "")) {
    stop("'values' must be a named vector when output = 'polygon'.")
  }

  for (name in value_names) {
    v[[name]] <- values[[name]]
  }

  if (isSf) {
    if (!requireNamespace("sf", quietly = TRUE)) {
      stop("Input is an 'sf' object but the 'sf' package is not installed.")
    }
    v <- sf::st_as_sf(v)
  }

  return(v)
}

.normalize_hull_coords <- function(coords) {
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

.find_antipodal_pairs <- function(coords, tol = 1e-12) {
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

.calc_extent_values <- function(hull, direction = c("ew", "ns"), method = "geo") {
  b <- terra::ext(hull)
  crs_hull <- terra::crs(hull)
  pt_sw <- terra::vect(cbind(b$xmin, b$ymin), crs = crs_hull)
  pt_se <- terra::vect(cbind(b$xmax, b$ymin), crs = crs_hull)
  pt_nw <- terra::vect(cbind(b$xmin, b$ymax), crs = crs_hull)
  pt_ne <- terra::vect(cbind(b$xmax, b$ymax), crs = crs_hull)

  values <- c()

  if ("ew" %in% direction) {
    ew_length <- mean(c(
      as.numeric(terra::distance(pt_sw, pt_se, method = method)),
      as.numeric(terra::distance(pt_nw, pt_ne, method = method))
    ))
    values <- c(values, ew_length = ew_length)
  }

  if ("ns" %in% direction) {
    ns_length <- mean(c(
      as.numeric(terra::distance(pt_sw, pt_nw, method = method)),
      as.numeric(terra::distance(pt_se, pt_ne, method = method))
    ))
    values <- c(values, ns_length = ns_length)
  }

  values
}

.calculate_geometric_attributes_single <- function(v, metrics = "all") {
  # Validate input
  if (!methods::is(v, "SpatVector")) {
    stop("'v' must be a SpatVector object")
  }

  if (nrow(v) != 1) {
    stop(
      "Input must contain exactly one polygon. Received ",
      nrow(v),
      " features."
    )
  }

  verbatimCRS <- terra::crs(v)
  v <- terra::project(v, "EPSG:4326")


  # Define all available metrics
  available_metrics <- c(
    "area", "perimeter", "compactness", "reock",
    "elongation_rectangle", "num_holes", "hole_area", "hole_area_pct",
    "num_polygons", "ew_length", "ns_length", "maxlength", "bearing",
    "northerness", "fractaldimension", "sinuosity", "shape_index",
    "circularity_ratio", "decimallongitude", "decimallatitude"
  )

  # Validate and normalize metrics parameter
  if (!is.character(metrics)) {
    stop("'metrics' must be a character string or vector")
  }

  if (length(metrics) == 1L && metrics == "all") {
    metrics_to_calc <- available_metrics
  } else {
    invalid_metrics <- setdiff(metrics, available_metrics)
    if (length(invalid_metrics) > 0) {
      stop(
        "Invalid metric names: ",
        paste(invalid_metrics, collapse = ", "),
        "\nAvailable metrics: ",
        paste(available_metrics, collapse = ", ")
      )
    }
    metrics_to_calc <- metrics
  }

  # --- Resolve implicit dependencies ---
  # Some metrics depend on intermediate values that must be computed first.

  need_area <- any(
    c("area", "hole_area_pct", "compactness", "reock",
      "fractaldimension", "shape_index", "circularity_ratio") %in% metrics_to_calc
  )
  need_perimeter <- any(
    c("perimeter", "compactness", "fractaldimension",
      "sinuosity", "shape_index") %in% metrics_to_calc
  )
  need_maxlength <- any(
    c("maxlength", "sinuosity", "circularity_ratio") %in% metrics_to_calc
  )
  need_bearing <- any(
    c("bearing", "northerness") %in% metrics_to_calc
  )
  need_hole_area <- any(
    c("hole_area", "hole_area_pct") %in% metrics_to_calc
  )

  # Determine which intermediate objects are needed
  need_hull <- need_maxlength || need_bearing ||
    any(c("elongation_rectangle", "ew_length", "ns_length") %in% metrics_to_calc)
  need_distant_pts <- need_maxlength || need_bearing
  need_centroid <- any(c("decimallongitude", "decimallatitude") %in% metrics_to_calc)
  need_mincircle <- "reock" %in% metrics_to_calc
  need_inh <- any(c("num_holes", "hole_area", "hole_area_pct") %in% metrics_to_calc)
  need_pols <- "num_polygons" %in% metrics_to_calc

  # --- Compute intermediate objects (each at most once) ---

  hull <- NULL
  if (need_hull) {
    hull <- terra::hull(v, type = "convex")
  }

  distant_pts <- NULL
  if (need_distant_pts) {
    # Compute only the pieces actually needed by downstream metrics.
    distant_pts <- get_distant_points(
      hull,
      isHull = TRUE,
      distance = need_maxlength,
      bearing = need_bearing,
      output = "value",
      by_feature = FALSE
    )
  }

  centroid <- NULL
  if (need_centroid) {
    centroid <- terra::centroids(v)
  }

  mincircle <- NULL
  if (need_mincircle) {
    mincircle <- terra::hull(v, type = "circle")
  }

  inh <- NULL
  if (need_inh) {
    inh <- terra::fillHoles(v, inverse = TRUE)
  }

  pols <- NULL
  if (need_pols) {
    pols <- terra::disagg(v)
  }

  # --- Compute base metrics ---

  area_val <- NULL
  if (need_area) {
    area_val <- terra::expanse(v, unit = "m", transform = TRUE)
  }

  perimeter_val <- NULL
  if (need_perimeter) {
    perimeter_val <- terra::perim(v)
  }

  maxlength_val <- NULL
  if (need_maxlength) {
    if (need_bearing) {
      maxlength_val <- distant_pts[["distance"]]
    } else {
      maxlength_val <- distant_pts
    }
  }

  bearing_val <- NULL
  if (need_bearing) {
    if (need_maxlength) {
      bearing_val <- distant_pts[["bearing"]]
    } else {
      bearing_val <- distant_pts
    }
  }

  hole_area_val <- NULL
  if (need_hole_area) {
    hole_area_val <- sum(terra::expanse(inh, unit = "m", transform = TRUE))
  }

  # --- Assign requested metrics to the output ---

  if ("area" %in% metrics_to_calc) {
    v$area <- area_val
  }

  if ("perimeter" %in% metrics_to_calc) {
    v$perimeter <- perimeter_val
  }

  if ("compactness" %in% metrics_to_calc) {
    v$compactness <- (4 * pi * area_val) / (perimeter_val^2)
  }

  if ("reock" %in% metrics_to_calc) {
    v$reock <- area_val / terra::expanse(mincircle, unit = "m", transform = TRUE)
  }

  if ("elongation_rectangle" %in% metrics_to_calc) {
    v$elongation_rectangle <- calc_elongation(
      hull,
      isHull = TRUE,
      output = "value",
      by_feature = FALSE
    )
  }

  if ("num_holes" %in% metrics_to_calc) {
    v$num_holes <- length(inh)
  }

  if ("hole_area" %in% metrics_to_calc) {
    v$hole_area <- hole_area_val
  }

  if ("hole_area_pct" %in% metrics_to_calc) {
    v$hole_area_pct <- (hole_area_val / area_val) * 100
  }

  if ("num_polygons" %in% metrics_to_calc) {
    v$num_polygons <- length(pols)
  }

  if (any(c("ew_length", "ns_length") %in% metrics_to_calc)) {
    extent_direction <- c()
    if ("ew_length" %in% metrics_to_calc) {
      extent_direction <- c(extent_direction, "ew")
    }
    if ("ns_length" %in% metrics_to_calc) {
      extent_direction <- c(extent_direction, "ns")
    }

    extent_pol <- calc_extent(
      hull,
      isHull = TRUE,
      direction = extent_direction,
      output = "polygon",
      by_feature = FALSE
    )
    if ("ew_length" %in% metrics_to_calc) {
      v$ew_length <- extent_pol$ew_length
    }
    if ("ns_length" %in% metrics_to_calc) {
      v$ns_length <- extent_pol$ns_length
    }
  }

  if ("maxlength" %in% metrics_to_calc) {
    v$maxlength <- maxlength_val
  }

  if ("bearing" %in% metrics_to_calc) {
    v$bearing <- bearing_val
  }

  if ("northerness" %in% metrics_to_calc) {
    v$northerness <- cos(pi * (bearing_val / 180))
  }

  if ("fractaldimension" %in% metrics_to_calc) {
    v$fractaldimension <- 2 * (log(perimeter_val) / log(area_val))
  }

  if ("sinuosity" %in% metrics_to_calc) {
    v$sinuosity <- perimeter_val / maxlength_val
  }

  if ("shape_index" %in% metrics_to_calc) {
    v$shape_index <- perimeter_val / (2 * sqrt(pi * area_val))
  }

  if ("circularity_ratio" %in% metrics_to_calc) {
    v$circularity_ratio <- (4 * area_val) / (pi * maxlength_val^2)
  }

  if ("decimallongitude" %in% metrics_to_calc) {
    v$decimallongitude <- terra::crds(centroid)[, 1]
  }

  if ("decimallatitude" %in% metrics_to_calc) {
    v$decimallatitude <- terra::crds(centroid)[, 2]
  }

  # Restore original CRS
  v <- terra::project(v, verbatimCRS)

  return(v)
}
