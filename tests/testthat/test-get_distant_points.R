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
