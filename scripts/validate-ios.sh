#!/bin/bash
# iOS validation script for Pantry
# Runs build and lint to validate iOS changes
# Usage: ./scripts/validate-ios.sh [--test]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_PROJECT="$PROJECT_ROOT/ios/pantry"
SCHEME="pantry"
DESTINATION="platform=iOS Simulator,name=iPhone 16"
RUN_TESTS=false

# Parse arguments
if [[ "$1" == "--test" ]]; then
    RUN_TESTS=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== Pantry iOS Validation ==="
echo ""

# Track failures
FAILED=0

# 1. SwiftLint (if installed)
echo -n "Linting... "
if command -v swiftlint &> /dev/null; then
    cd "$IOS_PROJECT"
    if swiftlint lint pantry --quiet 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}warnings${NC}"
    fi
else
    echo -e "${YELLOW}skipped (swiftlint not installed)${NC}"
    echo "  Install with: brew install swiftlint"
fi

# 2. Build
echo -n "Building... "
cd "$IOS_PROJECT"
if xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" -quiet build 2>&1 | tail -1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    FAILED=1
fi

# 3. Tests (only if --test flag provided)
if [ "$RUN_TESTS" = true ]; then
    echo -n "Testing... "
    if xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" -quiet test 2>&1 | grep -E "(Test Suite|Executed|passed|failed)" | tail -3; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        FAILED=1
    fi
else
    echo "Tests: skipped (use --test to run)"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed${NC}"
    exit 1
fi
