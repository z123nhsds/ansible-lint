#!/bin/bash
# cspell:ignore codecov
# Script to combine coverage reports from multiple parallel test runs
# This is a workaround for pytest-cov's default merging failure in CI environments

set -e  # Exit on any error
set -o pipefail  # Exit if any command in a pipeline fails

# Default values
COVERAGE_DIR="coverage"
OUTPUT_FILE="coverage.xml"
VERBOSE=0

# Print help message
print_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Combine coverage reports from multiple parallel test runs.

Options:
    -d, --dir DIR         Directory containing coverage files (default: coverage)
    -o, --output FILE     Output coverage XML file (default: coverage.xml)
    -v, --verbose         Enable verbose output
    -h, --help            Show this help message and exit

Example:
    $0 -d coverage -o coverage.xml
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            COVERAGE_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift 1
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            print_help >&2
            exit 1
            ;;
    esac
done

# Verbose logging function
log() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$@"
    fi
}

# Check if coverage tool is available
if ! command -v coverage &> /dev/null; then
    echo "Error: coverage tool not found. Please install coverage first." >&2
    echo "Install with: pip install coverage" >&2
    exit 1
fi

log "Starting coverage combination process..."
log "Coverage directory: $COVERAGE_DIR"
log "Output file: $OUTPUT_FILE"

# Create coverage directory if it doesn't exist
mkdir -p "$COVERAGE_DIR"

# 1. Find all coverage data files
# pytest-cov with parallel mode creates files like .coverage.hostname.pid.random
COVERAGE_FILES=()
while IFS= read -r -d '' file; do
    COVERAGE_FILES+=("$file")
done < <(find . -maxdepth 2 -name ".coverage*" -type f -print0 2>/dev/null)

if [[ ${#COVERAGE_FILES[@]} -eq 0 ]]; then
    echo "Warning: No coverage files found!" >&2
    exit 0
fi

log "Found ${#COVERAGE_FILES[@]} coverage file(s):"
for file in "${COVERAGE_FILES[@]}"; do
    log "  - $file"
done

# 2. Move all coverage files to a dedicated directory
log "Moving coverage files to $COVERAGE_DIR..."
for file in "${COVERAGE_FILES[@]}"; do
    mv "$file" "$COVERAGE_DIR/"
done

# 3. Combine the coverage files
log "Combining coverage files..."
cd "$COVERAGE_DIR" || exit 1

# Set COVERAGE_FILE to a temporary file for combination
export COVERAGE_FILE=".coverage.combined"

# Combine all coverage data files
coverage combine

# 4. Generate the XML report
log "Generating XML coverage report: $OUTPUT_FILE"
coverage xml -o "$OUTPUT_FILE"

# Optional: Generate a text report for debugging
if [[ $VERBOSE -eq 1 ]]; then
    log "Coverage summary:"
    coverage report
fi

# 5. Verify the output
if [[ -f "$OUTPUT_FILE" ]]; then
    log "Successfully generated coverage report: $OUTPUT_FILE"
    log "Report size: $(du -h "$OUTPUT_FILE")"
else
    echo "Error: Failed to generate coverage report!" >&2
    exit 1
fi

# 6. Clean up temporary combined file if needed
# Uncomment this if you don't want to keep the combined .coverage file
# rm -f "$COVERAGE_FILE"

log "Coverage combination completed successfully!"
