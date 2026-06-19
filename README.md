# geomattR

<!-- badges: start -->
<!-- badges: end -->

## Overview

`geomattR` provides a comprehensive toolkit for calculating geometric and morphometric attributes of spatial polygons. It computes area, perimeter, compactness, elongation, orientation, fractal dimension, and various shape indices using **geodesic measurements** for accuracy across different coordinate reference systems.

This package is particularly useful for:
- **Geospatial analysts** analyzing shape and size of geographic features
- **Urban planners** characterizing building and neighborhood geometry
- **Environmental scientists** studying habitat patch metrics
- **Remote sensing practitioners** extracting morphological features from vector data
- **Landscape ecologists** quantifying landscape structure
- **Political scientists** examining electoral district shapes
- **Epidemiologists** analyzing spatial spread patterns

All calculations use the [`terra`](https://github.com/rspatial/terra) package for efficient spatial data handling, with explicit geodesic methods ensuring accurate results regardless of input CRS (geographic or projected).

## Installation

Install from GitHub:

``` r
# Install devtools if needed
# install.packages("devtools")
devtools::install_github("gortegasolis/geomattR")
```

## Quick Start

``` r
library(geomattR)
library(terra)

# Create a sample polygon (WGS84 - geographic CRS)
coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
polygon <- vect(coords, type = "polygon", crs = "EPSG:4326")

# Calculate all geometric attributes (uses geodesic measurements automatically)
result <- calculate_geometric_attributes(polygon)

# View results
print(result)

# Calculate only specific metrics
result_subset <- calculate_geometric_attributes(
  polygon,
  metrics = c("area", "perimeter", "compactness", "bearing")
)
```

## Features

### Available Metrics

#### Size Metrics
- **area**: Total area in square meters (geodesic)
- **perimeter**: Total perimeter length in meters (geodesic)
- **hole_area**: Total area of interior holes
- **hole_area_pct**: Percentage of polygon occupied by holes

#### Shape Metrics
- **compactness**: Polsby-Popper compactness (0-1, where 1 = perfect circle)
- **reock**: Reock compactness (area/minimum enclosing circle area)
- **elongation_rectangle**: Elongation ratio from minimum bounding rectangle
- **shape_index**: Dimensionless shape complexity measure
- **circularity_ratio**: How closely polygon resembles a circle
- **fractaldimension**: Boundary complexity measure (typically 1-2)

#### Orientation Metrics
- **bearing**: Geographic bearing in degrees (south→north)
- **northerness**: Cosine of bearing (-1 to 1)
- **ew_length**: Average east-west extent in meters (geodesic)
- **ns_length**: Average north-south extent in meters (geodesic)
- **maxlength**: Maximum distance across polygon (geodesic)

#### Geometry Metrics
- **num_holes**: Number of interior holes
- **num_polygons**: Number of multi-part polygon components
- **decimallongitude**: Centroid X coordinate
- **decimallatitude**: Centroid Y coordinate
- **sinuosity**: Perimeter to maximum length ratio

### Geodesic Calculations

`geomattR` prioritizes geodesic calculations to ensure accuracy across different coordinate reference systems (CRS). When input polygons are in a projected CRS, the package automatically transforms them to a geographic CRS (WGS84) for geodesic measurements, then returns results in the original CRS.

## Example: Analyzing Building Footprints

``` r
library(geomattR)
library(terra)

# Load or create polygons (buildings, administrative boundaries, etc.)
buildings <- vect("path/to/buildings.shp")

# Calculate metrics for all buildings
building_metrics <- calculate_geometric_attributes(
  buildings,
  metrics = c("area", "perimeter", "compactness", "elongation_rectangle")
)

# View results
head(building_metrics)

# Use results for analysis
summary(building_metrics$compactness)
hist(building_metrics$area)
```

## Processing Multiple Polygons

For sequential processing:
``` r
polygons <- vect("path/to/polygons.shp")
results <- calculate_geometric_attributes(polygons)
```

For parallel processing:
``` r
library(parallel)

cl <- makeCluster(detectCores() - 1)
results <- calculate_geometric_attributes(polygons, cl = cl)
stopCluster(cl)
```

## Development

For developers, a build and check script is provided:

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

## Documentation

Full documentation is available in R:

``` r
?calculate_geometric_attributes
?calculate_geometric_attributes_single
?get_distant_points
?calc_elongation
```

## Related Packages

- **[terra](https://github.com/rspatial/terra)**: Foundational spatial data handling (required)
- **[sf](https://r-spatial.github.io/sf/)**: Alternative vector format support
- **[NLMR](https://github.com/ropensci/NLMR)**: Neutral landscape models with shape metrics
- **[landscapemetrics](https://r-spatial.github.io/landscapemetrics/)**: Comprehensive landscape ecology metrics

## Citation

If you use `geomattR` in your research, please cite it:

```r
citation("geomattR")
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on [GitHub](https://github.com/gortegasolis/geomattR).

## Author

Gabriel Ortega-Solis ([g.ortega.solis@gmail.com](mailto:g.ortega.solis@gmail.com))
ORCID: [0000-0002-0516-5694](https://orcid.org/0000-0002-0516-5694)

