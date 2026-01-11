test_that("get_distant_points returns valid structure", {
  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  result <- get_distant_points(pol)

  expect_true(is.list(result))
  expect_true(all(c("start_ll", "end_ll", "distance", "bearing") %in% names(result)))
  expect_true(methods::is(result$start_ll, "SpatVector"))
  expect_true(methods::is(result$end_ll, "SpatVector"))
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

  # start_ll should be southernmost (lower latitude)
  # end_ll should be northernmost (higher latitude)
  start_coords <- terra::crds(result$start_ll)
  end_coords <- terra::crds(result$end_ll)

  expect_true(start_coords[2] <= end_coords[2])
})
