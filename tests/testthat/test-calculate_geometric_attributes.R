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
