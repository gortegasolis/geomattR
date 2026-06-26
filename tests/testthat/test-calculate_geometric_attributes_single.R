test_that(".calculate_geometric_attributes_single works with all metrics", {
  # Create test polygon
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  # Test with all metrics
  result <- .calculate_geometric_attributes_single(pol, metrics = "all")

  # Check that result is a SpatVector
  expect_true(methods::is(result, "SpatVector"))

  # Check that all expected columns are present
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

test_that(".calculate_geometric_attributes_single works with subset of metrics", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  # Test with specific metrics
  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("area", "perimeter", "compactness")
  )

  # Check that only requested columns are present
  expect_true("area" %in% names(result))
  expect_true("perimeter" %in% names(result))
  expect_true("compactness" %in% names(result))

  # Check that unrequested columns are not present
  expect_false("bearing" %in% names(result))
})

test_that(".calculate_geometric_attributes_single validates input", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  # Test invalid input type
  expect_error(.calculate_geometric_attributes_single("not a SpatVector"))

  # Test multiple features (should error)
  multi_pol <- rbind(pol, pol)
  expect_error(.calculate_geometric_attributes_single(multi_pol))

  # Test invalid metric name
  expect_error(
    .calculate_geometric_attributes_single(pol, metrics = "invalid_metric")
  )
})

test_that(".calculate_geometric_attributes_single computes correct area", {
  # Create a simple square (1x1 degree at equator ~111km per degree)
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(pol, metrics = "area")

  # Area should be positive
  expect_true(result$area > 0)

  # Approximate area at equator should be around 111km x 111km = 12321 km2
  # Allow tolerance due to geodesic calculations
  expect_true(result$area > 1e10)
  expect_true(result$area < 2e10)
})

test_that(".calculate_geometric_attributes_single computes positive perimeter", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(pol, metrics = "perimeter")

  # Perimeter should be positive
  expect_true(result$perimeter > 0)
})

test_that(".calculate_geometric_attributes_single computes valid compactness", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("area", "perimeter", "compactness")
  )

  # Compactness should be between 0 and 1
  expect_true(result$compactness > 0)
  expect_true(result$compactness <= 1)
})

test_that(".calculate_geometric_attributes_single handles holes correctly", {
  # Build a single polygon feature with one interior ring.
  pol <- terra::vect(
    "POLYGON ((0 0, 0 4, 4 4, 4 0, 0 0), (1 1, 1 3, 3 3, 3 1, 1 1))",
    crs = "EPSG:4326"
  )

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("num_holes", "hole_area", "hole_area_pct")
  )

  # Should detect the hole
  expect_true(result$num_holes > 0)
  expect_true(result$hole_area > 0)
  expect_true(result$hole_area_pct > 0)
  expect_true(result$hole_area_pct < 100)
})

test_that(".calculate_geometric_attributes_single computes valid bearing", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(pol, metrics = "bearing")

  # Bearing should be between 0 and 360 degrees (or handle negative values)
  expect_true(!is.na(result$bearing))
  expect_true(result$bearing >= -180 & result$bearing <= 360)
})

test_that(".calculate_geometric_attributes_single computes valid northerness", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("bearing", "northerness")
  )

  # Northerness should be between -1 and 1
  expect_true(result$northerness >= -1)
  expect_true(result$northerness <= 1)
})

test_that(".calculate_geometric_attributes_single computes valid centroid", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("decimallongitude", "decimallatitude")
  )

  # Centroid should be within bounds
  expect_true(result$decimallongitude >= 0 & result$decimallongitude <= 1)
  expect_true(result$decimallatitude >= 0 & result$decimallatitude <= 1)
})
