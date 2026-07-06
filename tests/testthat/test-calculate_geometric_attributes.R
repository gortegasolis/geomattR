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

  print(outputs)

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

  print(outputs)

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
