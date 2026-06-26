.skip_if_proj_unavailable <- function() {
  probe <- suppressWarnings(
    try(
      terra::vect(
        cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)),
        type = "polygon",
        crs = "EPSG:4326"
      ),
      silent = TRUE
    )
  )

  if (inherits(probe, "try-error") || !nzchar(terra::crs(probe))) {
    skip("PROJ database is unavailable; skipping geodesic elongation tests")
  }
}

test_that("calc_elongation returns positive numeric value", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  out <- calc_elongation(pol)

  expect_type(out, "double")
  expect_true(out > 0)
})

test_that("calc_elongation uses precomputed hull consistently", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")
  hull <- terra::hull(pol, type = "convex")

  out_direct <- calc_elongation(pol, isHull = FALSE)
  out_hull <- calc_elongation(hull, isHull = TRUE)

  expect_equal(out_direct, out_hull)
})

test_that("calc_elongation reprojects projected input for geo and haversine", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol_ll <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")
  pol_3857 <- terra::project(pol_ll, "EPSG:3857")

  geo_ll <- calc_elongation(pol_ll, method = "geo")
  geo_3857 <- calc_elongation(pol_3857, method = "geo")
  hav_ll <- calc_elongation(pol_ll, method = "haversine")
  hav_3857 <- calc_elongation(pol_3857, method = "haversine")

  expect_equal(geo_3857, geo_ll, tolerance = 1e-6)
  expect_equal(hav_3857, hav_ll, tolerance = 1e-6)
})

test_that("calc_elongation polygon output appends elongation_rectangle", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  out <- calc_elongation(pol, output = "polygon")

  expect_true(methods::is(out, "SpatVector"))
  expect_true("elongation_rectangle" %in% names(out))
  expect_true(out$elongation_rectangle > 0)
})

test_that("calc_elongation validates output argument", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  expect_error(calc_elongation(pol, output = "invalid"))
  expect_error(calc_elongation(pol, output = c("value", "polygon")))
})

test_that("calc_elongation supports by_feature outputs", {
  .skip_if_proj_unavailable()

  p1 <- terra::vect(cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  p2 <- terra::vect(cbind(c(2, 2, 5, 5, 2), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  pol <- rbind(p1, p2)

  out_val <- calc_elongation(pol, output = "value", by_feature = TRUE)
  out_pol <- calc_elongation(pol, output = "polygon", by_feature = TRUE)

  expect_type(out_val, "double")
  expect_equal(length(out_val), 2)
  expect_true(methods::is(out_pol, "SpatVector"))
  expect_equal(nrow(out_pol), 2)
  expect_true("elongation_rectangle" %in% names(out_pol))
  expect_equal(as.numeric(out_pol$elongation_rectangle), as.numeric(out_val), tolerance = 1e-10)
})
