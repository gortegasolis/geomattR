# geomattR

<!-- badges: start -->

<!-- badges: end -->

## Overview

*Honestly, I use developing this package as a way to learn about spatial indices by decomposing their formulas and explaining to myself how they work while writing the documentation.*

`geomattR` provides a comprehensive toolkit for calculating geometric and morphometric attributes of spatial polygons. It computes area, perimeter, compactness, elongation, orientation, fractal dimension, and various shape indices.

This package is particularly useful for: - **Geospatial analysts** analyzing shape and size of geographic features - **Urban planners** characterizing building and neighborhood geometry - **Environmental scientists** studying habitat patch metrics - **Remote sensing practitioners** extracting morphological features from vector data - **Landscape ecologists** quantifying landscape structure - **Political scientists** examining electoral district shapes - **Epidemiologists** analyzing spatial spread patterns

Core spatial calculations use the [`terra`](https://github.com/rspatial/terra) package for efficient spatial data handling and geodesic measurement support, while [`geosphere`](https://CRAN.R-project.org/package=geosphere) is used for bearing estimation when a metric requires geographic coordinates. Distance- and area-based metrics are computed, and shape indices are derived from those quantities.

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

-   **area**: Total area in square meters.
-   **perimeter**: Total perimeter length in meters.
-   **hole_area**: Total area of interior holes in square meters.
-   **hole_area_pct**: Percentage of polygon occupied by holes: $HA\% = \frac{\text{hole\_area}}{\text{area}} \times 100$.

#### Shape Metrics

-   **compactness**: Polsby-Popper compactness, a circularity index that compares polygon area to the area of a circle with the same perimeter: $C = \frac{4\pi A}{P^2}$. Values closer to 1 indicate more compact (circle-like) shapes.
-   **reock**: Reock compactness, defined as polygon area relative to the area of its minimum enclosing circle: $R = \frac{A}{A_{MEC}}$. Values closer to 1 indicate that the polygon fills its enclosing circle more efficiently.
-   **elongation_rectangle**: Elongation index from the minimum bounding rectangle of the convex hull. In the current implementation, it is computed as the mean of the two largest side lengths divided by the mean of the two shortest side lengths: $E = \frac{\text{mean}(\text{long sides})}{\text{mean}(\text{short sides})}$.
-   **shape_index**: Dimensionless irregularity index comparing polygon perimeter to the perimeter of a circle with the same area: $SI = \frac{P}{2\sqrt{\pi A}}$. A value of 1 corresponds to a perfect circle; larger values indicate increasing irregularity.
-   **circularity_ratio**: Circularity index based on area and maximum hull distance: $CR = \frac{4A}{\pi L_{\max}^2}$.
-   **fractaldimension**: Perimeter-area scaling proxy for boundary complexity: $D = \frac{2\ln(P)}{\ln(A)}$.

#### Orientation Metrics

-   **bearing**: Geographic bearing of the maximum length line from southernmost to northernmost point in decimal degrees ($0^{\circ}$ to $360^{\circ}$).
-   **northerness**: Cosine of bearing: $N = \cos(\text{bearing} \times \frac{\pi}{180})$ (ranges from -1 to 1).
-   **ew_length**: Average east-west extent in meters: $EW = \frac{d(NW, NE) + d(SW, SE)}{2}$.
-   **ns_length**: Average north-south extent in meters: $NS = \frac{d(SW, NW) + d(SE, NE)}{2}$.
-   **maxlength**: Maximum distance across the convex hull: $L_{\max} = \max_{p_i, p_j} d(p_i, p_j)$.

#### Geometry Metrics

-   **num_holes**: Number of interior holes (rings).
-   **num_polygons**: Number of separate polygon parts (multi-part count).
-   **decimallongitude**: Centroid longitude in decimal degrees.
-   **decimallatitude**: Centroid latitude in decimal degrees.
-   **sinuosity**: Perimeter-to-diameter proxy (perimeter divided by maximum hull distance): $S = \frac{P}{L_{\max}}$.

### Geodesic Calculations

`geomattR` prioritizes geodesic calculations by default (`method = "geo"`), which makes the metrics suitable for continental or global scale studies. `haversine` and `cosine` are also supported for faster approximations or planar CRS. For methods that need geographic coordinates, the package will transform the geometry to WGS84 internally and then restore the output geometry to the original CRS when applicable.

Area, perimeter, extent, maximum distance, and bearing are computed according to the selected method. Derived shape indices (for example compactness, sinuosity, and fractaldimension) are calculated from those base quantities. For details on the methods `geo`, `haversine` and `cosine`, please refer to the documentation of the [`terra`](https://rspatial.github.io/terra/reference/distance.html) package.

## Documentation

Full documentation is available in R:

``` r
?calculate_geometric_attributes
?get_distant_points
?calc_elongation
```

## Related Packages

-   [**terra**](https://github.com/rspatial/terra): Foundational spatial data handling (required)
-   [**geosphere**](https://CRAN.R-project.org/package=geosphere): Geodetic bearing calculations (required)
-   [**sf**](https://r-spatial.github.io/sf/): Alternative vector format support
-   [**NLMR**](https://github.com/ropensci/NLMR): Neutral landscape models with shape metrics
-   [**landscapemetrics**](https://r-spatialecology.github.io/landscapemetrics/): Comprehensive landscape ecology metrics

## Citation

If you use `geomattR` in your research, please cite also `terra` and `geosphere`:

``` r
citation("geomattR")
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on [GitHub](https://github.com/gortegasolis/geomattR).

## Author

Gabriel Ortega-Solís ([g.ortega.solis\@gmail.com](mailto:g.ortega.solis@gmail.com)) ORCID: [0000-0002-0516-5694](https://orcid.org/0000-0002-0516-5694)
