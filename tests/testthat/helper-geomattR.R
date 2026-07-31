skip_if_proj_unavailable <- function() {
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
    testthat::skip("PROJ database is unavailable")
  }
}
