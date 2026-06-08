#!/bin/bash
set -euo pipefail

COVERAGE_ARTIFACTS_DIR="${1:-.}"
MERGED_DIR="${2:-coverage_merged}"

echo "=== Merging coverage data from parallel test shards ==="
echo "Source directory: ${COVERAGE_ARTIFACTS_DIR}"
echo "Output directory: ${MERGED_DIR}"

rm -rf "${MERGED_DIR}"
mkdir -p "${MERGED_DIR}"

COVERAGE_FILES=$(find "${COVERAGE_ARTIFACTS_DIR}" -name '.coverage.*' -type f 2>/dev/null || true)
COVERAGE_COUNT=$(echo "${COVERAGE_FILES}" | grep -c '.' || echo "0")

if [ "${COVERAGE_COUNT}" -eq 0 ]; then
    echo "ERROR: No .coverage.* files found in ${COVERAGE_ARTIFACTS_DIR}"
    echo "Available files:"
    find "${COVERAGE_ARTIFACTS_DIR}" -type f 2>/dev/null || echo "  (none)"
    exit 1
fi

echo "Found ${COVERAGE_COUNT} coverage data files:"
echo "${COVERAGE_FILES}" | while read -r f; do
    echo "  $(basename "$(dirname "$f")")/$(basename "$f")"
done

echo "Copying coverage data files to merge directory..."
echo "${COVERAGE_FILES}" | while read -r f; do
    cp "$f" "${MERGED_DIR}/"
done

cd "${MERGED_DIR}"

echo "Combining coverage data with: python -m coverage combine"
python -m coverage combine

echo "Generating coverage.xml..."
python -m coverage xml -o coverage.xml

echo "Generating coverage.json..."
python -m coverage json -o coverage.json

echo "Generating coverage report:"
python -m coverage report --fail-under=0

echo "=== Coverage merge complete ==="
echo "Output files:"
ls -la coverage.xml coverage.json 2>/dev/null || echo "  (output files missing)"