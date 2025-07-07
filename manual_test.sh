#!/bin/bash

# Manual testing script for LunaCopy to verify functionality
# This script tests the core features without relying on BATS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Function to print test results
print_test_result() {
    local test_name="$1"
    local result="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to cleanup test files
cleanup() {
    rm -rf test_temp_* 2>/dev/null || true
}

# Test 1: Basic usage and help
test_basic_usage() {
    echo "Testing basic usage and help..."
    
    # Test with no arguments
    if ./lunacopy.sh 2>&1 | grep -q "Usage:"; then
        print_test_result "Shows usage with no arguments" "PASS"
    else
        print_test_result "Shows usage with no arguments" "FAIL"
    fi
    
    # Test with one argument
    if ./lunacopy.sh hash 2>&1 | grep -q "Usage:"; then
        print_test_result "Shows usage with one argument" "PASS"
    else
        print_test_result "Shows usage with one argument" "FAIL"
    fi
    
    # Test with invalid action
    echo "test content" > test_temp_file.txt
    if ./lunacopy.sh invalid test_temp_file.txt 2>&1 | grep -q "Usage:"; then
        print_test_result "Shows usage with invalid action" "PASS"
    else
        print_test_result "Shows usage with invalid action" "FAIL"
    fi
    rm -f test_temp_file.txt
}

# Test 2: Single file hashing
test_single_file_hashing() {
    echo "Testing single file hashing..."
    
    # Create test file
    echo "Hello World" > test_temp_single.txt
    
    # Test MD5 hashing
    if echo "1" | ./lunacopy.sh hash test_temp_single.txt >/dev/null 2>&1 && [ -f test_temp_single.txt.md5 ]; then
        # Verify hash content
        expected_hash="e59ff97941044f85df5297e1c302d260"
        actual_hash=$(cut -d' ' -f1 test_temp_single.txt.md5)
        if [ "$expected_hash" = "$actual_hash" ]; then
            print_test_result "MD5 hashing of single file" "PASS"
        else
            print_test_result "MD5 hashing of single file (wrong hash)" "FAIL"
        fi
    else
        print_test_result "MD5 hashing of single file" "FAIL"
    fi
    
    # Clean up
    rm -f test_temp_single.txt test_temp_single.txt.md5
    
    # Test SHA256 hashing
    echo "Hello World" > test_temp_single.txt
    if echo "2" | ./lunacopy.sh hash test_temp_single.txt >/dev/null 2>&1 && [ -f test_temp_single.txt.sha256 ]; then
        # Verify hash content
        expected_hash="d2a84f4b8b650937ec8f73cd8be2c74add5a911ba64df27458ed8229da804a26"
        actual_hash=$(cut -d' ' -f1 test_temp_single.txt.sha256)
        if [ "$expected_hash" = "$actual_hash" ]; then
            print_test_result "SHA256 hashing of single file" "PASS"
        else
            print_test_result "SHA256 hashing of single file (wrong hash)" "FAIL"
        fi
    else
        print_test_result "SHA256 hashing of single file" "FAIL"
    fi
    
    rm -f test_temp_single.txt test_temp_single.txt.sha256
}

# Test 3: Directory hashing
test_directory_hashing() {
    echo "Testing directory hashing..."
    
    # Create test directory
    mkdir -p test_temp_dir
    echo "File 1 content" > test_temp_dir/file1.txt
    echo "File 2 content" > test_temp_dir/file2.txt
    mkdir -p test_temp_dir/subdir
    echo "Subdir file content" > test_temp_dir/subdir/file3.txt
    
    # Test MD5 directory hashing
    if echo "1" | ./lunacopy.sh hash test_temp_dir >/dev/null 2>&1 && [ -f test_temp_dir/test_temp_dir.md5 ]; then
        # Check if all files are included
        file_count=$(wc -l < test_temp_dir/test_temp_dir.md5)
        if [ "$file_count" -eq 3 ]; then
            print_test_result "MD5 directory hashing" "PASS"
        else
            print_test_result "MD5 directory hashing (wrong file count: $file_count)" "FAIL"
        fi
    else
        print_test_result "MD5 directory hashing" "FAIL"
    fi
    
    rm -rf test_temp_dir
}

# Test 4: File verification
test_file_verification() {
    echo "Testing file verification..."
    
    # Create test file and hash
    echo "Test content for verification" > test_temp_verify.txt
    echo "1" | ./lunacopy.sh hash test_temp_verify.txt >/dev/null 2>&1
    
    # Test successful verification
    if ./lunacopy.sh verify test_temp_verify.txt.md5 >/dev/null 2>&1; then
        print_test_result "File verification (success)" "PASS"
    else
        print_test_result "File verification (success)" "FAIL"
    fi
    
    # Test failed verification (modify file)
    echo "Modified content" > test_temp_verify.txt
    if ! ./lunacopy.sh verify test_temp_verify.txt.md5 >/dev/null 2>&1; then
        print_test_result "File verification (failure detection)" "PASS"
    else
        print_test_result "File verification (failure detection)" "FAIL"
    fi
    
    rm -f test_temp_verify.txt test_temp_verify.txt.md5 test_temp_verify.txt.md5.*.error.log
}

# Test 5: Directory verification
test_directory_verification() {
    echo "Testing directory verification..."
    
    # Create test directory and hash
    mkdir -p test_temp_verify_dir
    echo "File 1" > test_temp_verify_dir/file1.txt
    echo "File 2" > test_temp_verify_dir/file2.txt
    echo "1" | ./lunacopy.sh hash test_temp_verify_dir >/dev/null 2>&1
    
    # Test successful verification
    if echo "1" | ./lunacopy.sh verify test_temp_verify_dir >/dev/null 2>&1; then
        print_test_result "Directory verification (success)" "PASS"
    else
        print_test_result "Directory verification (success)" "FAIL"
    fi
    
    # Test failed verification (modify file)
    echo "Modified" > test_temp_verify_dir/file1.txt
    if ! echo "1" | ./lunacopy.sh verify test_temp_verify_dir >/dev/null 2>&1; then
        print_test_result "Directory verification (failure detection)" "PASS"
    else
        print_test_result "Directory verification (failure detection)" "FAIL"
    fi
    
    rm -rf test_temp_verify_dir
}

# Test 6: Import functionality
test_import_functionality() {
    echo "Testing import functionality..."
    
    # Create legacy format file
    cat > test_temp_legacy.md5 << 'EOF'
; Generated by Microsoft (R) File Checksum Integrity Verifier (FCIV) Version 2.05
;
; MD5 checksums generated at 2023-08-18 12:00:00
d41d8cd98f00b204e9800998ecf8427e *file1.txt
5d41402abc4b2a76b9719d911017c592 *file2.txt
EOF
    
    # Test import
    if echo "y" | ./lunacopy.sh import test_temp_legacy.md5 >/dev/null 2>&1; then
        # Check if backup was created and new format is correct
        if [ -f test_temp_legacy.md5.backup ] && [ -f test_temp_legacy.md5 ]; then
            # Check format conversion
            if grep -q "d41d8cd98f00b204e9800998ecf8427e  file1.txt" test_temp_legacy.md5; then
                print_test_result "Import legacy format" "PASS"
            else
                print_test_result "Import legacy format (format error)" "FAIL"
            fi
        else
            print_test_result "Import legacy format (missing files)" "FAIL"
        fi
    else
        print_test_result "Import legacy format" "FAIL"
    fi
    
    rm -f test_temp_legacy.md5 test_temp_legacy.md5.backup
}

# Test 7: Path validation
test_path_validation() {
    echo "Testing path validation..."
    
    # Test nonexistent file for hash
    if ./lunacopy.sh hash nonexistent_file.txt 2>&1 | grep -q "does not exist"; then
        print_test_result "Path validation for hash (nonexistent file)" "PASS"
    else
        print_test_result "Path validation for hash (nonexistent file)" "FAIL"
    fi
    
    # Test nonexistent file for verify
    if ./lunacopy.sh verify nonexistent_file.txt 2>&1 | grep -q "does not exist"; then
        print_test_result "Path validation for verify (nonexistent file)" "PASS"
    else
        print_test_result "Path validation for verify (nonexistent file)" "FAIL"
    fi
}

# Test 8: Append functionality
test_append_functionality() {
    echo "Testing append functionality..."
    
    # Create test directory with initial files
    mkdir -p test_temp_append
    echo "File 1" > test_temp_append/file1.txt
    echo "File 2" > test_temp_append/file2.txt
    
    # Create initial hash
    echo "1" | ./lunacopy.sh hash test_temp_append >/dev/null 2>&1
    initial_count=$(wc -l < test_temp_append/test_temp_append.md5)
    
    # Add new file
    echo "File 3" > test_temp_append/file3.txt
    
    # Test append
    if echo -e "1\n1" | ./lunacopy.sh hash test_temp_append >/dev/null 2>&1; then
        new_count=$(wc -l < test_temp_append/test_temp_append.md5)
        if [ "$new_count" -gt "$initial_count" ]; then
            print_test_result "Append new files to existing hash" "PASS"
        else
            print_test_result "Append new files (count not increased)" "FAIL"
        fi
    else
        print_test_result "Append new files to existing hash" "FAIL"
    fi
    
    rm -rf test_temp_append
}

# Main test execution
main() {
    echo "=========================================="
    echo "LunaCopy Manual Test Suite"
    echo "=========================================="
    echo ""
    
    # Make sure script is executable
    chmod +x lunacopy.sh
    
    # Run all tests
    cleanup
    test_basic_usage
    test_single_file_hashing
    test_directory_hashing
    test_file_verification
    test_directory_verification
    test_import_functionality
    test_path_validation
    test_append_functionality
    cleanup
    
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ All tests passed! LunaCopy is working correctly.${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}❌ Some tests failed. Please review the results above.${NC}"
        exit 1
    fi
}

# Run the tests
main "$@"