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
    skip("PROJ database is unavailable; skipping geodesic extent tests")
  }
}

test_that("calc_extent returns numeric values for single directions", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  ew <- calc_extent(pol, direction = "ew")
  ns <- calc_extent(pol, direction = "ns")

  expect_type(ew, "double")
  expect_type(ns, "double")
  expect_true(ew > 0)
  expect_true(ns > 0)
})

test_that("calc_extent returns both values when both directions are requested", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  out <- calc_extent(pol, direction = c("ns", "ew"), output = "value")

  expect_type(out, "double")
  expect_true("ew_length" %in% names(out))
  expect_true("ns_length" %in% names(out))
  expect_true(out[["ew_length"]] > 0)
  expect_true(out[["ns_length"]] > 0)
})

test_that("calc_extent polygon output appends only requested columns", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  out <- calc_extent(pol, direction = "ew", output = "polygon")

  expect_true(methods::is(out, "SpatVector"))
  expect_true("ew_length" %in% names(out))
  expect_false("ns_length" %in% names(out))
  expect_true(out$ew_length > 0)
})

test_that("calc_extent polygon output appends both columns when both directions requested", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  out <- calc_extent(pol, direction = c("ew", "ns"), output = "polygon")

  expect_true(methods::is(out, "SpatVector"))
  expect_true("ew_length" %in% names(out))
  expect_true("ns_length" %in% names(out))
  expect_true(out$ew_length > 0)
  expect_true(out$ns_length > 0)
})

test_that("calc_extent validates output argument", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")

  expect_error(calc_extent(pol, output = "invalid"))
  expect_error(calc_extent(pol, output = c("value", "polygon")))
  expect_error(calc_extent(pol, direction = "invalid"))
})

test_that("calc_extent uses precomputed hull consistently", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")
  hull <- terra::hull(pol, type = "convex")

  ew_direct <- calc_extent(pol, isHull = FALSE, direction = "ew")
  ew_hull <- calc_extent(hull, isHull = TRUE, direction = "ew")
  ns_direct <- calc_extent(pol, isHull = FALSE, direction = "ns")
  ns_hull <- calc_extent(hull, isHull = TRUE, direction = "ns")

  both_direct <- calc_extent(pol, isHull = FALSE, direction = c("ew", "ns"))
  both_hull <- calc_extent(hull, isHull = TRUE, direction = c("ew", "ns"))

  expect_equal(ew_direct, ew_hull)
  expect_equal(ns_direct, ns_hull)
  expect_equal(both_direct, both_hull)
})

test_that("calc_extent reprojects projected input for geo and haversine", {
  .skip_if_proj_unavailable()

  coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
  pol_ll <- terra::vect(coords, type = "polygon", crs = "EPSG:4326")
  pol_3857 <- terra::project(pol_ll, "EPSG:3857")

  ew_geo_ll <- calc_extent(pol_ll, direction = "ew", method = "geo")
  ew_geo_3857 <- calc_extent(pol_3857, direction = "ew", method = "geo")
  ns_hav_ll <- calc_extent(pol_ll, direction = "ns", method = "haversine")
  ns_hav_3857 <- calc_extent(pol_3857, direction = "ns", method = "haversine")

  expect_equal(ew_geo_3857, ew_geo_ll, tolerance = 1e-6)
  expect_equal(ns_hav_3857, ns_hav_ll, tolerance = 1e-6)
})

test_that("calc_extent supports by_feature value output", {
  .skip_if_proj_unavailable()

  p1 <- terra::vect(cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  p2 <- terra::vect(cbind(c(2, 2, 4, 4, 2), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  pol <- rbind(p1, p2)

  out_one <- calc_extent(pol, direction = "ew", output = "value", by_feature = TRUE)
  out_both <- calc_extent(pol, direction = c("ew", "ns"), output = "value", by_feature = TRUE)

  expect_type(out_one, "double")
  expect_equal(length(out_one), 2)
  expect_true(is.data.frame(out_both))
  expect_equal(nrow(out_both), 2)
  expect_true(all(c("ew_length", "ns_length") %in% names(out_both)))
})

test_that("calc_extent supports by_feature polygon output", {
  .skip_if_proj_unavailable()

  p1 <- terra::vect(cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  p2 <- terra::vect(cbind(c(2, 2, 4, 4, 2), c(0, 1, 1, 0, 0)), type = "polygon", crs = "EPSG:4326")
  pol <- rbind(p1, p2)

  out <- calc_extent(pol, direction = c("ew", "ns"), output = "polygon", by_feature = TRUE)

  expect_true(methods::is(out, "SpatVector"))
  expect_equal(nrow(out), 2)
  expect_true(all(c("ew_length", "ns_length") %in% names(out)))
  expect_false(isTRUE(all.equal(out$ew_length[1], out$ew_length[2])))
})
