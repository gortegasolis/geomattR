#' Calculate Geometric Attributes in Parallel (Deprecated Wrapper)
#'
#' This function is retained for backward compatibility. It delegates to
#' \code{\link{calculate_geometric_attributes}} which now natively supports
#' parallel execution via the \code{cl} argument.
#'
#' @inheritParams calculate_geometric_attributes
#'
#' @return A SpatVector object with added columns containing the requested
#'   geometric attributes. Equivalent to calling
#'   \code{calculate_geometric_attributes(v, metrics, cl)}.
#'
#' @details
#' New code should use \code{\link{calculate_geometric_attributes}} directly
#' with the \code{cl} parameter. This wrapper exists so that existing code using
#' \code{calculate_geometric_attributes_parallel()} continues to work without
#' modification.
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
  calculate_geometric_attributes(v, metrics = metrics, cl = cl)
}
