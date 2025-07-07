#!/bin/bash

# Test runner script for lunacopy.sh

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo "Error: bats (Bash Automated Testing System) is not installed."
    echo "Please install bats to run the tests."
    echo ""
    echo "On Ubuntu/Debian: sudo apt-get install bats"
    echo "On RHEL/CentOS: sudo yum install bats"
    echo "On macOS: brew install bats-core"
    echo ""
    echo "Or install from source: https://github.com/bats-core/bats-core"
    exit 1
fi

# Check if lunacopy.sh exists
if [[ ! -f "lunacopy.sh" ]]; then
    echo "Error: lunacopy.sh not found in current directory."
    exit 1
fi

# Make sure lunacopy.sh is executable
chmod +x lunacopy.sh

# Check if test_helper.sh exists
if [[ ! -f "test_helper.sh" ]]; then
    echo "Error: test_helper.sh not found in current directory."
    exit 1
fi

echo "Starting LunaCopy automated test suite..."
echo "========================================"
echo ""

# Run the tests
if bats test_lunacopy.bats; then
    echo ""
    echo "========================================"
    echo "✅ All tests passed successfully!"
    echo "LunaCopy script appears to be working correctly."
    exit 0
else
    echo ""
    echo "========================================"
    echo "❌ Some tests failed!"
    echo "Please review the test output above for details."
    exit 1
fi
