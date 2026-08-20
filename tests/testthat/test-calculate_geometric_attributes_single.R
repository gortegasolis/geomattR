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

  # Bearing is an axial orientation measured south -> north, so it must lie
  # within [-90, 90].
  expect_true(!is.na(result$bearing))
  expect_true(result$bearing >= -90 & result$bearing <= 90)
})

test_that(".calculate_geometric_attributes_single computes valid northerness", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("bearing", "northerness")
  )

  # Bearing is confined to [-90, 90], so northerness = cos(bearing) is in [0, 1].
  expect_true(result$northerness >= 0)
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

test_that(".calculate_geometric_attributes_single returns degree centroid on projected CRS", {
  # 1000 m square in Web Mercator (metres)
  pol <- terra::vect(
    cbind(c(0, 0, 1000, 1000, 0), c(0, 1000, 1000, 0, 0)),
    type = "polygon",
    crs = "EPSG:3857"
  )

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("decimallongitude", "decimallatitude"),
    method = "cosine"
  )

  # Must be degrees, not metres
  expect_true(abs(result$decimallongitude) <= 180)
  expect_true(abs(result$decimallatitude) <= 90)
  expect_gt(result$decimallongitude, 0)
  expect_gt(result$decimallatitude, 0)
})

test_that("fractaldimension follows the FRAGSTATS convention", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("area", "perimeter", "fractaldimension")
  )

  expected <- 2 * log(0.25 * result$perimeter) / log(result$area)
  expect_equal(as.numeric(result$fractaldimension), as.numeric(expected))
  # A square should give D ~= 1 (geodesic P/A make it slightly inexact)
  expect_equal(as.numeric(result$fractaldimension), 1, tolerance = 1e-3)
})

test_that("hole_area_pct uses gross area as denominator", {
  # 4x4 square with a 2x2 hole: hole = 1/4 of gross area
  pol <- terra::vect(
    "POLYGON ((0 0, 0 4, 4 4, 4 0, 0 0), (1 1, 1 3, 3 3, 3 1, 1 1))",
    crs = "EPSG:4326"
  )

  result <- .calculate_geometric_attributes_single(
    pol,
    metrics = c("area", "hole_area", "hole_area_pct", "num_holes")
  )

  expect_equal(as.numeric(result$num_holes), 1)
  expected_pct <- 100 * result$hole_area / (result$area + result$hole_area)
  expect_equal(as.numeric(result$hole_area_pct), as.numeric(expected_pct))
  # Gross-area denominator must differ from the old net-area one
  old_pct <- 100 * result$hole_area / result$area
  expect_gt(abs(result$hole_area_pct - old_pct), 1e-6)
})

test_that(".prepare_metric_input rejects empty input", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  expect_error(
    .prepare_metric_input(pol[0, ]),
    "at least one feature"
  )
})
