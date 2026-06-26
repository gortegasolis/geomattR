test_that("get_distant_points returns valid structure", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- get_distant_points(pol)

  expect_true(is.list(result))
  expect_true(all(c("south_point", "north_point", "distance", "bearing") %in% names(result)))
  expect_true(methods::is(result$south_point, "SpatVector"))
  expect_true(methods::is(result$north_point, "SpatVector"))
  expect_true(is.numeric(result$distance))
  expect_true(is.numeric(result$bearing))
})

test_that("get_distant_points returns positive distance", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- get_distant_points(pol)

  expect_true(result$distance > 0)
})

test_that("get_distant_points respects south-north ordering", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- get_distant_points(pol)

  # south_point should be southernmost (lower latitude)
  # north_point should be northernmost (higher latitude)
  start_coords <- terra::crds(result$south_point)
  end_coords <- terra::crds(result$north_point)

  expect_true(start_coords[2] <= end_coords[2])
})

test_that("get_distant_points is deterministic for tied diameters", {
  coords <- cbind(c(0, 0, 2, 2, 0), c(0, 2, 2, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- get_distant_points(pol)
  south <- terra::crds(result$south_point)
  north <- terra::crds(result$north_point)

  expect_equal(as.numeric(south[1]), 0)
  expect_equal(as.numeric(south[2]), 0)
  expect_equal(as.numeric(north[1]), 2)
  expect_equal(as.numeric(north[2]), 2)
})

test_that("get_distant_points distance matches exhaustive hull search", {
  exhaustive_max_distance <- function(v) {
    hull <- terra::hull(v, type = "convex")
    coords <- terra::crds(hull)
    if (nrow(coords) > 1 && all(abs(coords[1, 1:2] - coords[nrow(coords), 1:2]) == 0)) {
      coords <- coords[-nrow(coords), , drop = FALSE]
    }

    points_hull <- terra::vect(coords, crs = terra::crs(v))
    dists <- terra::distance(points_hull, method = "geo")
    max(as.matrix(dists))
  }

  coords <- cbind(
    c(-1.5, -0.2, 1.8, 2.0, 0.9, -0.8, -1.5),
    c(0.2, 1.7, 1.2, -0.3, -1.6, -1.2, 0.2)
  )
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- get_distant_points(pol)
  ref <- exhaustive_max_distance(pol)

  expect_equal(as.numeric(result$distance), as.numeric(ref), tolerance = 1e-6)
})

test_that("get_distant_points supports by_feature output", {
  p1 <- terra::vect(cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  p2 <- terra::vect(cbind(c(2, 2, 5, 5, 2), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  pol <- rbind(p1, p2)

  result <- get_distant_points(pol, by_feature = TRUE)

  expect_true(is.list(result))
  expect_equal(length(result), 2)
  expect_true(all(vapply(result, function(x) is.list(x), logical(1))))
  expect_true(all(vapply(result, function(x) methods::is(x$south_point, "SpatVector"), logical(1))))
  expect_true(all(vapply(result, function(x) methods::is(x$north_point, "SpatVector"), logical(1))))
})

test_that("get_distant_points supports value output modes", {
  coords <- cbind(c(0, 0, 2, 2, 0), c(0, 2, 2, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  out_distance <- get_distant_points(pol, distance = TRUE, bearing = FALSE, output = "value")
  out_bearing <- get_distant_points(pol, distance = FALSE, bearing = TRUE, output = "value")
  out_both <- get_distant_points(pol, distance = TRUE, bearing = TRUE, output = "value")

  expect_type(out_distance, "double")
  expect_type(out_bearing, "double")
  expect_true(out_distance > 0)
  expect_true(!is.na(out_bearing))
  expect_type(out_both, "double")
  expect_true(all(c("distance", "bearing") %in% names(out_both)))
})

test_that("get_distant_points supports polygon output mode", {
  coords <- cbind(c(0, 0, 2, 2, 0), c(0, 2, 2, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  out <- get_distant_points(pol, distance = TRUE, bearing = TRUE, output = "polygon")

  expect_true(methods::is(out, "SpatVector"))
  expect_true("distance" %in% names(out))
  expect_true("bearing" %in% names(out))
  expect_true(out$distance > 0)
  expect_true(!is.na(out$bearing))
})

test_that("get_distant_points supports by_feature value output", {
  p1 <- terra::vect(cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  p2 <- terra::vect(cbind(c(2, 2, 5, 5, 2), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  pol <- rbind(p1, p2)

  out_one <- get_distant_points(pol, distance = TRUE, bearing = FALSE, output = "value", by_feature = TRUE)
  out_both <- get_distant_points(pol, distance = TRUE, bearing = TRUE, output = "value", by_feature = TRUE)

  expect_type(out_one, "double")
  expect_equal(length(out_one), 2)
  expect_true(is.data.frame(out_both))
  expect_equal(nrow(out_both), 2)
  expect_true(all(c("distance", "bearing") %in% names(out_both)))
})
