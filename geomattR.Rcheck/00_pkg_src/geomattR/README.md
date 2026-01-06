# geomattR

<!-- badges: start -->
<!-- badges: end -->

The goal of geomattR is to provide a simple set of functions to calculate geometric attributes (e.g., area, perimeter, centroid, compactness) of spatial polygons using R. This package is particularly useful for geospatial analysts, urban planners, and environmental scientists who need to analyze the shape and size of geographical features.

## Installation

You can install the development version of geomattR from [GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("gortegasolis/geomattR")
```

## Development

For developers, a build and check script is provided to streamline the development workflow:

```bash
# Full build, check, install, and test
./build_check.sh

# Skip PDF manual generation (faster)
./build_check.sh --no-manual

# Available options:
#   --no-manual    Skip PDF manual generation
#   --no-install   Skip package installation
#   --no-tests     Skip running tests
#   --no-clean     Skip cleaning previous builds
#   --help         Show help message
```

## How to use it

The main function of the package is `calculate_geometric_attributes()`, which takes a SpatVector object as input and returns the same object with various geometric attributes added as new columns.

```r
library(geomattR)
library(terra)
library(tidyterra)
library(geodata)

## Create a SpatVector object
pol <- gadm("CHL", level = 1, path = tempdir()) |>
    filter(NAME_1 == "Los Lagos")

## Calculate geometric attributes
pol_with_attributes <- calculate_geometric_attributes(pol)
```

