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

## How to use it

The main function of the package is `calculate_geometric_attributes()`, which takes a SpatVector object as input and returns the same object with various geometric attributes added as new columns.

```r
library(geomattR)
library(terra)
library(rnaturalearth)
## Create a SpatVector object
pol <- ne_download(scale = 10, type = "admin_1", category = "cultural", returnclass = "sf") |>
    dplyr::filter(name == "Los Lagos") |>
    terra::vect()

## Calculate geometric attributes
pol_with_attributes <- calculate_geometric_attributes(pol)
```

