#' Calculate Geometric Attributes in Parallel
#'
#' Calculates geometric attributes for multiple polygons. If a cluster is provided,
#' processes polygons in parallel; otherwise defaults to sequential processing.
#'
#' @param v A SpatVector object representing one or more polygons.
#' @param metrics Character string or vector specifying which metrics to calculate.
#'   See [calculate_geometric_attributes()] for available options.
#' @param cl A cluster object created by [parallel::makeCluster()], or NULL (default).
#'   If NULL, the function will process polygons sequentially. To enable parallel
#'   processing, pass an explicit cluster object.
#'
#' @return A SpatVector object with the same structure as input, with added
#'   columns containing the requested geometric attributes.
#'
#' @details
#' This function processes each polygon independently using the internal
#' single-polygon function. If a cluster is provided via the \code{cl}
#' parameter, it will process polygons in parallel. Otherwise, it defaults to
#' sequential processing (equivalent to calling [calculate_geometric_attributes()]).
#'
#' For a single polygon, this function simply calls
#' [calculate_geometric_attributes()] directly.
#'
#' To use parallel processing, create a cluster first:
#' ```r
#' cl <- parallel::makeCluster(parallel::detectCores() - 1)
#' result <- calculate_geometric_attributes_parallel(polygons, cl = cl)
#' parallel::stopCluster(cl)
#' ```
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(terra)
#'
#' # Load multiple polygons
#' polygons <- vect("path/to/polygons.shp")
#'
#' # Process sequentially (default)
#' result <- calculate_geometric_attributes_parallel(polygons)
#'
#' # Process in parallel with explicit cluster
#' cl <- parallel::makeCluster(parallel::detectCores() - 1)
#' result <- calculate_geometric_attributes_parallel(polygons, cl = cl)
#' parallel::stopCluster(cl)
#' }
calculate_geometric_attributes_parallel <- function(v, metrics = "all", cl = NULL) {
  # Validate input
  if (!methods::is(v, "SpatVector")) {
    stop("'v' must be a SpatVector object")
  }

  # If no cluster provided, delegate to sequential version
  if (is.null(cl)) {
    return(calculate_geometric_attributes(v, metrics = metrics))
  }

  n_features <- nrow(v)

  # Single feature: process directly
  if (n_features == 1) {
    return(calculate_geometric_attributes_single(v, metrics = metrics))
  }

  # Multiple features with cluster: process in parallel
  # Split the SpatVector into individual features
  feature_list <- lapply(1:n_features, function(i) v[i, ])

  # Prepare the cluster: export necessary functions and packages
  parallel::clusterEvalQ(cl, library(terra))
  parallel::clusterExport(cl,
    c("calculate_geometric_attributes_single", "calc_elongation", "calc_extent_ew",
      "calc_extent_ns", "get_distant_points"),
    envir = environment()
  )

  # Process in parallel
  results <- parallel::parLapply(cl, feature_list, function(poly) {
    calculate_geometric_attributes_single(poly, metrics = metrics)
  })

  # Combine results
  result <- do.call(rbind, results)
  return(result)
}
