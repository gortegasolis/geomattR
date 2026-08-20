# Prepare polygon input for downstream metrics.
# Main options: set isHull = TRUE to reuse a precomputed hull; method controls
# whether hulls are reprojected to lon/lat for geodesic distance calculations.
# build_hull = FALSE skips hull construction (e.g. by_feature loops, where the
# whole-set hull would be computed and discarded).
.prepare_metric_input <- function(v, isHull = FALSE, method = "geo", build_hull = TRUE) {

  isSf <- inherits(v, "sf")
  if (isSf) {
    v <- terra::vect(v)
  }

  if (!methods::is(v, "SpatVector")) {
    cli::cli_abort(
      "{.arg v} must be a SpatVector object",
      call = rlang::caller_env()
    )
  }

  if (nrow(v) == 0L) {
    cli::cli_abort(
      "{.arg v} must contain at least one feature.",
      call = rlang::caller_env()
    )
  }

  geom_type <- unique(tolower(as.character(terra::geomtype(v))))
  if (!all(geom_type %in% "polygons")) {
    cli::cli_abort(
      "{.arg v} must contain polygon geometries, not {.val {geom_type}}.",
      call = rlang::caller_env()
    )
  }

  if (any(!terra::is.valid(v))) {
    cli::cli_warn(
      "{.arg v} contains invalid geometries; metrics may be unreliable.",
      call = rlang::caller_env()
    )
  }

  hull <- NULL
  if (build_hull) {
    hull <- if (isHull) v else terra::hull(v, type = "convex")
    if (method %in% c("geo", "haversine") && !terra::is.lonlat(hull)) {
      hull <- terra::project(hull, "EPSG:4326")
    }
  }

  list(v = v, hull = hull, isSf = isSf)
}

# Return metric results either as raw values or appended polygon attributes.
# Main options: output = "value" returns numeric results; output = "polygon"
# adds named values back onto the original geometry and restores sf inputs.
.return_metric_output <- function(v, isSf, output = "value", values) {
  if (length(output) != 1L) {
    cli::cli_abort(
      "Output type must be a single value: either 'value' or 'polygon'.",
      call = rlang::caller_env()
    )
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
    cli::cli_abort(
      "{.arg values} must be a named vector when {.code output = 'polygon'}.",
      call = rlang::caller_env()
    )
  }

  for (name in value_names) {
    v[[name]] <- values[[name]]
  }

  if (isSf) {
    if (!requireNamespace("sf", quietly = TRUE)) {
      cli::cli_abort(
        "Input is an {.pkg sf} object but the {.pkg sf} package is not installed.",
        call = rlang::caller_env()
      )
    }
    v <- sf::st_as_sf(v)
  }

  return(v)
}

# Clean hull coordinates before rotating-calipers calculations.
# Main options: coords should contain x/y columns; repeated, missing, and
# closing vertices are removed, and polygon orientation is normalized.
.normalize_hull_coords <- function(coords) {
  eps <- sqrt(.Machine$double.eps)

  xy <- as.matrix(coords[, 1:2, drop = FALSE])
  xy <- xy[stats::complete.cases(xy), , drop = FALSE]

  if (nrow(xy) == 0L) {
    cli::cli_abort("Hull has no valid coordinates.", call = rlang::caller_env())
  }

  if (nrow(xy) > 1L) {
    keep <- c(
      TRUE,
      rowSums(abs(xy[-1, , drop = FALSE] - xy[-nrow(xy), , drop = FALSE])) > eps
    )
    xy <- xy[keep, , drop = FALSE]
  }

  if (nrow(xy) > 1L && all(abs(xy[1, ] - xy[nrow(xy), ]) < eps)) {
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

# Local Lambert azimuthal equal-area CRS (metres) centred on a feature.
# Used to run planar GEOS hull minimization in a space that is locally
# distance- and area-faithful instead of in raw lon/lat degrees.
.local_planar_crs <- function(v) {
  ctr <- terra::crds(terra::centroids(v))
  sprintf(
    "+proj=laea +lon_0=%.10f +lat_0=%.10f +datum=WGS84 +units=m +no_defs",
    ctr[1], ctr[2]
  )
}

# Compute a GEOS hull (e.g. "circle", "rectangle") in a local planar CRS for
# lon/lat input, then project it back to the input CRS. Projected input is
# handled directly in its own CRS.
.local_hull <- function(v, type) {
  if (terra::is.lonlat(v)) {
    crs_local <- .local_planar_crs(v)
    hull_local <- terra::hull(terra::project(v, crs_local), type = type)
    terra::project(hull_local, terra::crs(v))
  } else {
    terra::hull(v, type = type)
  }
}

# Compute east-west and north-south extents from hull bounding-box corners.
# Main options: direction selects which axes to return, and method is passed to
# terra::distance() for the edge-length calculations.
.calc_extent_values <- function(
  hull,
  direction = c("ew", "ns"),
  method = "geo"
) {

  if (nrow(hull) != 1) {
    cli::cli_abort(
      "Input must contain exactly one polygon. Received {nrow(hull)} feature{?s}.",
      call = rlang::caller_env()
    )
  }

  b <- terra::ext(hull)
  if (terra::is.lonlat(hull) && (b$xmax - b$xmin) > 180) {
    cli::cli_warn(
      c(
        "Hull longitude span exceeds 180 degrees; it may cross the antimeridian.",
        "i" = "Extent is computed from the raw bounding box and is unreliable across the antimeridian."
      ),
      call = rlang::caller_env()
    )
  }
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

# Calculate all requested metrics for a single polygon feature.
# Main options: metrics = "all" expands to the full supported set; method
# controls whether geographic calculations trigger a temporary lon/lat reprojection.
.calculate_geometric_attributes_single <- function(
  v,
  metrics = "all",
  method = "geo"
) {
  if (nrow(v) != 1) {
    cli::cli_abort(
      "Input must contain exactly one polygon. Received {nrow(v)} feature{?s}.",
      call = rlang::caller_env()
    )
  }

  if (method %in% c("geo", "haversine") && !terra::is.lonlat(v)) {
    transform_v <- TRUE
    verbatimCRS <- terra::crs(v)
    v <- terra::project(v, "EPSG:4326")
  } else {
    transform_v <- FALSE
  }

  # Define all available metrics
  available_metrics <- c(
    "area",
    "perimeter",
    "compactness",
    "reock",
    "elongation_rectangle",
    "num_holes",
    "hole_area",
    "hole_area_pct",
    "num_polygons",
    "ew_length",
    "ns_length",
    "maxlength",
    "bearing",
    "northerness",
    "fractaldimension",
    "sinuosity",
    "shape_index",
    "circularity_ratio",
    "decimallongitude",
    "decimallatitude"
  )

  # Validate and normalize metrics parameter
  if (!is.character(metrics)) {
    cli::cli_abort(
      "{.arg metrics} must be a character string or vector.",
      call = rlang::caller_env()
    )
  }

  if (length(metrics) == 1L && metrics == "all") {
    metrics_to_calc <- available_metrics
  } else {
    invalid_metrics <- setdiff(metrics, available_metrics)
    if (length(invalid_metrics) > 0) {
      cli::cli_abort(
        c(
          "Invalid metric name{?s}: {.val {invalid_metrics}}",
          "i" = "Available metrics: {.val {available_metrics}}"
        ),
        call = rlang::caller_env()
      )
    }
    metrics_to_calc <- metrics
  }

  # --- Resolve implicit dependencies ---
  # Some metrics depend on intermediate values that must be computed first.

  need_area <- any(
    c(
      "area",
      "hole_area_pct",
      "compactness",
      "reock",
      "fractaldimension",
      "shape_index",
      "circularity_ratio"
    ) %in%
      metrics_to_calc
  )
  need_perimeter <- any(
    c(
      "perimeter",
      "compactness",
      "fractaldimension",
      "sinuosity",
      "shape_index"
    ) %in%
      metrics_to_calc
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
  need_hull <- need_maxlength ||
    need_bearing ||
    any(
      c("elongation_rectangle", "ew_length", "ns_length") %in% metrics_to_calc
    )
  need_distant_pts <- need_maxlength || need_bearing
  need_centroid <- any(
    c("decimallongitude", "decimallatitude") %in% metrics_to_calc
  )
  need_mincircle <- "reock" %in% metrics_to_calc
  need_inh <- any(
    c("hole_area", "hole_area_pct") %in% metrics_to_calc
  )
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
      by_feature = FALSE,
      method = method
    )
  }

  centroid <- NULL
  if (need_centroid) {
    centroid <- terra::centroids(v)
    # decimallongitude/decimallatitude must always be in degrees
    if (!terra::is.lonlat(centroid)) {
      centroid <- terra::project(centroid, "EPSG:4326")
    }
  }

  mincircle <- NULL
  if (need_mincircle) {
    # Minimizing in lon/lat degrees distorts the circle at high latitudes;
    # minimize in a local equal-area projection and project the result back.
    mincircle <- .local_hull(v, type = "circle")
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
    # v is already lon/lat when transform_v is TRUE, so no transform argument
    # is needed: expanse() is geodesic on lon/lat and Cartesian otherwise.
    area_val <- terra::expanse(v, unit = "m")
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
    hole_area_val <- sum(terra::expanse(inh, unit = "m"))
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
    v$reock <- area_val / terra::expanse(mincircle, unit = "m")
  }

  if ("elongation_rectangle" %in% metrics_to_calc) {
    v$elongation_rectangle <- calc_elongation(
      hull,
      isHull = TRUE,
      output = "value",
      by_feature = FALSE,
      method = method
    )
  }

  if ("num_holes" %in% metrics_to_calc) {
    # Count interior rings from the geometry dump rather than relying on how
    # fillHoles(inverse = TRUE) packs features. Hole numbering can restart
    # per part, so count unique (part, hole) combinations.
    geom_mat <- terra::geom(v)
    hole_rows <- geom_mat[geom_mat[, "hole"] > 0, c("part", "hole"), drop = FALSE]
    v$num_holes <- nrow(unique(hole_rows))
  }

  if ("hole_area" %in% metrics_to_calc) {
    v$hole_area <- hole_area_val
  }

  if ("hole_area_pct" %in% metrics_to_calc) {
    # expanse() is net of holes, so add the hole area back to get the gross
    # area used as the denominator.
    v$hole_area_pct <- (hole_area_val / (area_val + hole_area_val)) * 100
  }

  if ("num_polygons" %in% metrics_to_calc) {
    v$num_polygons <- nrow(pols)
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
      by_feature = FALSE,
      method = method
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
    # FRAGSTATS convention: the 0.25 correction adjusts the perimeter for the
    # raster-origin bias of the index; expect values in [1, 2] for A > 0.
    v$fractaldimension <- 2 * log(0.25 * perimeter_val) / log(area_val)
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
  if (transform_v) {
    v <- terra::project(v, verbatimCRS)
  }

  return(v)
}
