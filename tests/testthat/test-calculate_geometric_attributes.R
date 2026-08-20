test_that("calculate_geometric_attributes works with single polygon", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- calculate_geometric_attributes(pol, metrics = c("area", "perimeter"))

  expect_true(methods::is(result, "SpatVector"))
  expect_true(nrow(result) == 1)
  expect_true("area" %in% names(result))
  expect_true("perimeter" %in% names(result))
})

test_that("calculate_geometric_attributes works with multiple polygons", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")
  multi_pol <- rbind(pol, pol)

  result <- calculate_geometric_attributes(multi_pol, metrics = c("area", "perimeter"))

  expect_true(methods::is(result, "SpatVector"))
  expect_true(nrow(result) == 2)
  expect_true(all(result$area > 0))
})

test_that("calculate_geometric_attributes validates input", {
  expect_error(calculate_geometric_attributes("not a SpatVector"))
})

test_that("calculate_geometric_attributes returns all metrics when requested", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- calculate_geometric_attributes(pol, metrics = "all")

  expected_cols <- c(
    "area", "perimeter", "compactness", "reock",
    "elongation_rectangle", "num_holes", "hole_area", "hole_area_pct",
    "num_polygons", "ew_length", "ns_length", "maxlength", "bearing",
    "northerness", "fractaldimension", "sinuosity", "shape_index",
    "circularity_ratio", "decimallongitude", "decimallatitude"
  )

  for (col in expected_cols) {
    expect_true(col %in% names(result))
  }
})

test_that("calculate_geometric_attributes compares geo haversine and cosine methods", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol_ll <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")
  pol_3857 <- terra::project(pol_ll, "EPSG:3857")

  outputs <- list(
    geo = list(
      ll = calculate_geometric_attributes(pol_ll, metrics = c("area", "perimeter", "maxlength"), method = "geo"),
      projected = calculate_geometric_attributes(pol_3857, metrics = c("area", "perimeter", "maxlength"), method = "geo")
    ),
    haversine = list(
      ll = calculate_geometric_attributes(pol_ll, metrics = c("area", "perimeter", "maxlength"), method = "haversine"),
      projected = calculate_geometric_attributes(pol_3857, metrics = c("area", "perimeter", "maxlength"), method = "haversine")
    ),
    cosine = list(
      ll = calculate_geometric_attributes(pol_ll, metrics = c("area", "perimeter", "maxlength"), method = "cosine"),
      projected = calculate_geometric_attributes(pol_3857, metrics = c("area", "perimeter", "maxlength"), method = "cosine")
    )
  )

  expect_equal(outputs$geo$projected$area, outputs$geo$ll$area, tolerance = 1e-6)
  expect_equal(outputs$geo$projected$perimeter, outputs$geo$ll$perimeter, tolerance = 1e-6)
  expect_equal(outputs$haversine$projected$area, outputs$haversine$ll$area, tolerance = 1e-6)
  expect_equal(outputs$haversine$projected$maxlength, outputs$haversine$ll$maxlength, tolerance = 1e-6)
  expect_true(is.finite(outputs$cosine$ll$maxlength))
  expect_true(is.finite(outputs$cosine$projected$maxlength))
  expect_true(all(vapply(outputs, function(method_output) methods::is(method_output$ll, "SpatVector"), logical(1))))
})

test_that("calculate_geometric_attributes handles all metrics across geo haversine and cosine", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol_3857 <- terra::project(terra::vect(coords, type = "polygon", crs = "EPSG:4326"), "EPSG:3857")

  outputs <- list(
    geo = calculate_geometric_attributes(pol_3857, metrics = "all", method = "geo"),
    haversine = calculate_geometric_attributes(pol_3857, metrics = "all", method = "haversine"),
    cosine = calculate_geometric_attributes(pol_3857, metrics = "all", method = "cosine")
  )

  expected_cols <- c(
    "area", "perimeter", "compactness", "reock",
    "elongation_rectangle", "num_holes", "hole_area", "hole_area_pct",
    "num_polygons", "ew_length", "ns_length", "maxlength", "bearing",
    "northerness", "fractaldimension", "sinuosity", "shape_index",
    "circularity_ratio", "decimallongitude", "decimallatitude"
  )

  for (method_name in names(outputs)) {
    result <- outputs[[method_name]]
    expect_true(methods::is(result, "SpatVector"))
    expect_equal(nrow(result), 1)
    expect_true(all(expected_cols %in% names(result)))
    expect_false(terra::is.lonlat(result))
    expect_true(all(vapply(expected_cols, function(col) is.finite(unlist(result[[col]])[1]), logical(1))))
  }
})

test_that("reock is consistent for cosine method on projected CRS", {
  pol_ll <- terra::vect(
    cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)),
    type = "polygon",
    crs = "EPSG:4326"
  )
  pol_proj <- terra::project(pol_ll, "EPSG:3857")

  result <- calculate_geometric_attributes(
    pol_proj,
    metrics = c("area", "reock"),
    method = "cosine"
  )

  expect_true(result$reock > 0)
  expect_true(result$reock <= 1)
})

test_that("vectorised simple-metrics path matches per-feature results", {
  skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  p1 <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")
  p2 <- terra::shift(p1, dx = 5, dy = 10)
  v2 <- rbind(p1, p2)
  v2_proj <- terra::project(v2, "EPSG:3857")

  mets <- c("area", "perimeter", "decimallongitude", "decimallatitude")
  fast <- calculate_geometric_attributes(v2, metrics = mets)

  for (i in seq_len(2)) {
    slow <- calculate_geometric_attributes(v2[i, ], metrics = mets)
    for (m in mets) {
      expect_equal(as.numeric(fast[[m]][[1]][i]), as.numeric(slow[[m]][[1]][1]))
    }
  }

  # Projected CRS + cosine must also match (no reprojection on that path)
  fast_c <- calculate_geometric_attributes(v2_proj, metrics = mets, method = "cosine")
  for (i in seq_len(2)) {
    slow_c <- calculate_geometric_attributes(v2_proj[i, ], metrics = mets, method = "cosine")
    for (m in mets) {
      expect_equal(as.numeric(fast_c[[m]][[1]][i]), as.numeric(slow_c[[m]][[1]][1]))
    }
  }

  # Invalid metric names still error
  expect_error(calculate_geometric_attributes(v2, metrics = c("area", "bogus")))
})
