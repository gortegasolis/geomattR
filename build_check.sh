#!/bin/bash

# Build, Check, and Test Script for geomattR Package
# This script automates the R package development workflow

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Package name and version
PKG_NAME="geomattR"
PKG_VERSION=$(grep "^Version:" DESCRIPTION | cut -d' ' -f2)
PKG_TAR="${PKG_NAME}_${PKG_VERSION}.tar.gz"

# Functions
print_step() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Parse command line arguments
SKIP_MANUAL=false
INSTALL_PKG=true
RUN_TESTS=true
CLEAN_BUILD=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-manual)
            SKIP_MANUAL=true
            shift
            ;;
        --no-install)
            INSTALL_PKG=false
            shift
            ;;
        --no-tests)
            RUN_TESTS=false
            shift
            ;;
        --no-clean)
            CLEAN_BUILD=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-manual     Skip PDF manual generation"
            echo "  --no-install    Skip package installation"
            echo "  --no-tests      Skip running tests"
            echo "  --no-clean      Skip cleaning previous builds"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Start
print_step "Starting ${PKG_NAME} Package Build and Check Process"
echo "Package: ${PKG_NAME}"
echo "Version: ${PKG_VERSION}"
echo ""

# Step 1: Clean previous builds
if [ "$CLEAN_BUILD" = true ]; then
    print_step "Step 1: Cleaning Previous Builds"
    
    if [ -d "${PKG_NAME}.Rcheck" ]; then
        rm -rf "${PKG_NAME}.Rcheck"
        print_success "Removed ${PKG_NAME}.Rcheck directory"
    fi
    
    if [ -f "${PKG_TAR}" ]; then
        rm -f "${PKG_TAR}"
        print_success "Removed ${PKG_TAR}"
    fi
    
    # Clean other temporary files
    find . -name "*.o" -o -name "*.so" -o -name "*.dll" | xargs rm -f 2>/dev/null || true
    print_success "Cleaned temporary files"
else
    print_warning "Skipping clean step (--no-clean flag)"
fi

# Step 2: Generate Documentation with roxygen2
print_step "Step 2: Generating Documentation with roxygen2"
Rscript -e "roxygen2::roxygenise()" || {
    print_error "Documentation generation failed"
    exit 1
}
print_success "Documentation generated successfully"

# Step 3: Build the package
print_step "Step 3: Building Package"
R CMD build . || {
    print_error "Package build failed"
    exit 1
}

if [ -f "${PKG_TAR}" ]; then
    print_success "Package built successfully: ${PKG_TAR}"
else
    print_error "Package tarball not found: ${PKG_TAR}"
    exit 1
fi

# Step 4: Run R CMD check
print_step "Step 4: Running R CMD Check"

CHECK_OPTS=""
if [ "$SKIP_MANUAL" = true ]; then
    CHECK_OPTS="--no-manual"
    print_warning "Skipping PDF manual generation"
fi

R CMD check $CHECK_OPTS "${PKG_TAR}" || {
    print_error "R CMD check failed"
    echo ""
    echo "Check the log file for details:"
    echo "${SCRIPT_DIR}/${PKG_NAME}.Rcheck/00check.log"
    exit 1
}
print_success "R CMD check completed successfully"

# Step 5: Install the package
if [ "$INSTALL_PKG" = true ]; then
    print_step "Step 5: Installing Package"
    R CMD INSTALL "${PKG_TAR}" || {
        print_error "Package installation failed"
        exit 1
    }
    print_success "Package installed successfully"
else
    print_warning "Skipping package installation (--no-install flag)"
fi

# Step 6: Run tests
if [ "$RUN_TESTS" = true ] && [ "$INSTALL_PKG" = true ]; then
    print_step "Step 6: Running Package Tests"
    
    # Create a simple test script
    TEST_SCRIPT=$(cat <<'EOF'
library(geomattR)
library(terra)

cat("Testing package functions...\n\n")

# Create a simple test polygon
coords <- cbind(c(0, 0, 1, 1, 0), c(0, 1, 1, 0, 0))
pol <- vect(coords, type='polygon', crs='EPSG:4326')

# Test 1: Single feature with specific metrics
cat("Test 1: calculate_geometric_attributes_single()... ")
tryCatch({
    result <- calculate_geometric_attributes_single(pol, metrics = c("area", "perimeter"))
    if (nrow(result) == 1 && "area" %in% names(result)) {
        cat("PASSED\n")
    } else {
        stop("Unexpected result")
    }
}, error = function(e) {
    cat("FAILED\n")
    print(e)
    quit(status = 1)
})

# Test 2: Main function with all metrics
cat("Test 2: calculate_geometric_attributes() with all metrics... ")
tryCatch({
    result <- calculate_geometric_attributes(pol, metrics = "all")
    expected_cols <- c("area", "perimeter", "compactness", "bearing")
    if (all(expected_cols %in% names(result))) {
        cat("PASSED\n")
    } else {
        stop("Missing expected columns")
    }
}, error = function(e) {
    cat("FAILED\n")
    print(e)
    quit(status = 1)
})

# Test 3: Multiple polygons
cat("Test 3: Multiple polygons... ")
tryCatch({
    pol2 <- rbind(pol, pol)
    result <- calculate_geometric_attributes(pol2, metrics = c("area", "perimeter"))
    if (nrow(result) == 2) {
        cat("PASSED\n")
    } else {
        stop("Unexpected number of rows")
    }
}, error = function(e) {
    cat("FAILED\n")
    print(e)
    quit(status = 1)
})

cat("\nAll tests passed!\n")
EOF
)
    
    echo "$TEST_SCRIPT" | Rscript - || {
        print_error "Tests failed"
        exit 1
    }
    print_success "All tests passed"
elif [ "$RUN_TESTS" = false ]; then
    print_warning "Skipping tests (--no-tests flag)"
else
    print_warning "Skipping tests (package not installed)"
fi

# Final summary
print_step "Build and Check Complete!"
echo -e "${GREEN}✓ Package ${PKG_NAME} ${PKG_VERSION} is ready${NC}"
echo ""
echo "Summary:"
echo "  - Documentation: Generated"
echo "  - Build: ${PKG_TAR}"
echo "  - Check: Passed"
if [ "$INSTALL_PKG" = true ]; then
    echo "  - Installation: Successful"
fi
if [ "$RUN_TESTS" = true ] && [ "$INSTALL_PKG" = true ]; then
    echo "  - Tests: Passed"
fi
echo ""
echo "Next steps:"
echo "  - Review check log: ${PKG_NAME}.Rcheck/00check.log"
echo "  - Load package in R: library(${PKG_NAME})"
echo "  - View documentation: ?calculate_geometric_attributes"
echo ""
