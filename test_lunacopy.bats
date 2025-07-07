#!/usr/bin/env bats

# Load test helper functions
source ./test_helper.sh

# Setup and teardown functions
setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

# Test basic usage and help
@test "lunacopy shows usage when called with wrong number of arguments" {
    run "$LUNACOPY_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "lunacopy shows usage when called with one argument" {
    run "$LUNACOPY_SCRIPT" "hash"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "lunacopy shows usage when called with invalid action" {
    create_test_file "test.txt" "content"
    run "$LUNACOPY_SCRIPT" "invalid" "test.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

# Test path validation
@test "lunacopy fails when path does not exist for hash operation" {
    run "$LUNACOPY_SCRIPT" "hash" "nonexistent.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "does not exist" ]]
}

@test "lunacopy fails when path does not exist for verify operation" {
    run "$LUNACOPY_SCRIPT" "verify" "nonexistent.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "does not exist" ]]
}

# Test single file hashing - MD5
@test "hash single file with MD5" {
    create_test_file "test.txt" "Hello World"
    
    run run_lunacopy_with_input "1" "hash" "test.txt"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "New testfile \"test.txt.md5\" written successfully" ]]
    
    # Verify the hash file was created
    [ -f "test.txt.md5" ]
    
    # Verify the content format
    run verify_lunacopy_format "test.txt.md5"
    [ "$status" -eq 0 ]
    
    # Check that the hash matches expected value
    local expected_hash="e59ff97941044f85df5297e1c302d260"
    local actual_hash=$(cut -d' ' -f1 "test.txt.md5")
    [ "$expected_hash" = "$actual_hash" ]
}

# Test single file hashing - SHA256
@test "hash single file with SHA256" {
    create_test_file "test.txt" "Hello World"
    
    run run_lunacopy_with_input "2" "hash" "test.txt"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "New testfile \"test.txt.sha256\" written successfully" ]]
    
    # Verify the hash file was created
    [ -f "test.txt.sha256" ]
    
    # Verify the content format
    run verify_lunacopy_format "test.txt.sha256"
    [ "$status" -eq 0 ]
    
    # Check that the hash matches expected value
    local expected_hash="d2a84f4b8b650937ec8f73cd8be2c74add5a911ba64df27458ed8229da804a26"
    local actual_hash=$(cut -d' ' -f1 "test.txt.sha256")
    [ "$expected_hash" = "$actual_hash" ]
}

# Test file overwrite confirmation
@test "hash single file with existing hash file - overwrite denied" {
    create_test_file "test.txt" "Hello World"
    create_test_file "test.txt.md5" "existing content"
    
    run run_lunacopy_with_input $'1\nn' "hash" "test.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Operation cancelled by the user" ]]
    
    # Verify original file wasn't modified
    [ "$(cat test.txt.md5)" = "existing content" ]
}

@test "hash single file with existing hash file - overwrite accepted" {
    create_test_file "test.txt" "Hello World"
    create_test_file "test.txt.md5" "existing content"
    
    run run_lunacopy_with_input $'1\ny' "hash" "test.txt"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "New testfile \"test.txt.md5\" written successfully" ]]
    
    # Verify file was updated with proper hash
    run verify_lunacopy_format "test.txt.md5"
    [ "$status" -eq 0 ]
}

# Test directory hashing
@test "hash directory with MD5" {
    create_test_directory "testdir"
    
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "New testfile \"testdir.md5\" written successfully" ]]
    
    # Verify the hash file was created in the directory
    [ -f "testdir/testdir.md5" ]
    
    # Verify it contains hashes for all files
    local line_count=$(count_lines "testdir/testdir.md5")
    [ "$line_count" -eq 3 ]
    
    # Verify format
    run verify_lunacopy_format "testdir/testdir.md5"
    [ "$status" -eq 0 ]
}

@test "hash directory with SHA256" {
    create_test_directory "testdir"
    
    run run_lunacopy_with_input "2" "hash" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "New testfile \"testdir.sha256\" written successfully" ]]
    
    # Verify the hash file was created in the directory
    [ -f "testdir/testdir.sha256" ]
    
    # Verify it contains hashes for all files
    local line_count=$(count_lines "testdir/testdir.sha256")
    [ "$line_count" -eq 3 ]
}

# Test directory hashing with existing hash file
@test "hash directory - append new files to existing hash file" {
    create_test_directory "testdir"
    
    # Create initial hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Add a new file
    create_test_file "testdir/newfile.txt" "New content"
    
    # Append new files
    run run_lunacopy_with_input $'1\n1' "hash" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "New files have been hashed and added to the existing testfile" ]]
    
    # Verify the hash file now contains 4 entries
    local line_count=$(count_lines "testdir/testdir.md5")
    [ "$line_count" -eq 4 ]
}

@test "hash directory - no new files to append" {
    create_test_directory "testdir"
    
    # Create initial hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Try to append without new files
    run run_lunacopy_with_input $'1\n1' "hash" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No new files have been detected" ]]
}

@test "hash directory - re-hash everything" {
    create_test_directory "testdir"
    
    # Create initial hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Re-hash everything
    run run_lunacopy_with_input $'1\n2\ny' "hash" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "New testfile \"testdir.md5\" written successfully" ]]
}

@test "hash directory - re-hash cancelled" {
    create_test_directory "testdir"
    
    # Create initial hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Cancel re-hash
    run run_lunacopy_with_input $'1\n2\nn' "hash" "testdir"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Operation cancelled by the user" ]]
}

@test "hash directory - exit without modification" {
    create_test_directory "testdir"
    
    # Create initial hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Exit without modification
    run run_lunacopy_with_input $'1\n3' "hash" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Exited without modifying the testfile" ]]
}

# Test verification of single files
@test "verify single file - MD5 success" {
    create_test_file "test.txt" "Hello World"
    
    # Create hash file
    run run_lunacopy_with_input "1" "hash" "test.txt"
    [ "$status" -eq 0 ]
    
    # Verify the file
    run "$LUNACOPY_SCRIPT" "verify" "test.txt.md5"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All files verified successfully" ]]
}

@test "verify single file - SHA256 success" {
    create_test_file "test.txt" "Hello World"
    
    # Create hash file
    run run_lunacopy_with_input "2" "hash" "test.txt"
    [ "$status" -eq 0 ]
    
    # Verify the file
    run "$LUNACOPY_SCRIPT" "verify" "test.txt.sha256"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All files verified successfully" ]]
}

@test "verify single file - file modified (failure)" {
    create_test_file "test.txt" "Hello World"
    
    # Create hash file
    run run_lunacopy_with_input "1" "hash" "test.txt"
    [ "$status" -eq 0 ]
    
    # Modify the file
    echo "Modified content" > "test.txt"
    
    # Verify should fail
    run "$LUNACOPY_SCRIPT" "verify" "test.txt.md5"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Verification errors detected" ]]
    
    # Check that error log was created
    [ -f test.txt.md5.*.error.log ]
}

@test "verify single file - missing testfile" {
    run "$LUNACOPY_SCRIPT" "verify" "nonexistent.md5"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "does not exist" ]]
}

@test "verify single file - invalid extension" {
    create_test_file "test.txt" "content"
    
    run "$LUNACOPY_SCRIPT" "verify" "test.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

# Test verification of directories
@test "verify directory - MD5 success" {
    create_test_directory "testdir"
    
    # Create hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Verify the directory
    run run_lunacopy_with_input "1" "verify" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All files verified successfully" ]]
}

@test "verify directory - SHA256 success" {
    create_test_directory "testdir"
    
    # Create hash file
    run run_lunacopy_with_input "2" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Verify the directory
    run run_lunacopy_with_input "2" "verify" "testdir"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All files verified successfully" ]]
}

@test "verify directory - file modified (failure)" {
    create_test_directory "testdir"
    
    # Create hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Modify a file
    echo "Modified content" > "testdir/file1.txt"
    
    # Verify should fail
    run run_lunacopy_with_input "1" "verify" "testdir"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Verification errors detected" ]]
    
    # Check that error log was created
    [ -f testdir/testdir.md5.*.error.log ]
}

@test "verify directory - missing testfile" {
    create_test_directory "testdir"
    
    run run_lunacopy_with_input "1" "verify" "testdir"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

# Test import functionality
@test "import legacy MD5 format" {
    create_legacy_md5 "legacy.md5"
    
    # Import the file
    run run_lunacopy_with_input "y" "import" "legacy.md5"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Conversion complete" ]]
    
    # Verify backup was created
    [ -f "legacy.md5.backup" ]
    
    # Verify new file format
    [ -f "legacy.md5" ]
    run verify_lunacopy_format "legacy.md5"
    [ "$status" -eq 0 ]
    
    # Verify content was converted (should have 3 lines)
    local line_count=$(count_lines "legacy.md5")
    [ "$line_count" -eq 3 ]
}

@test "import legacy SHA256 format" {
    create_legacy_sha256 "legacy.sha256"
    
    # Import the file
    run run_lunacopy_with_input "y" "import" "legacy.sha256"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Conversion complete" ]]
    
    # Verify backup was created
    [ -f "legacy.sha256.backup" ]
    
    # Verify new file format
    [ -f "legacy.sha256" ]
    run verify_lunacopy_format "legacy.sha256"
    [ "$status" -eq 0 ]
}

@test "import - cancel operation" {
    create_legacy_md5 "legacy.md5"
    
    # Cancel import
    run run_lunacopy_with_input "n" "import" "legacy.md5"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Operation cancelled by the user" ]]
    
    # Verify original file wasn't modified
    [ -f "legacy.md5" ]
    [ ! -f "legacy.md5.backup" ]
}

@test "import - invalid extension" {
    create_test_file "test.txt" "content"
    
    run "$LUNACOPY_SCRIPT" "import" "test.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid extension" ]]
}

@test "import - nonexistent file" {
    run "$LUNACOPY_SCRIPT" "import" "nonexistent.md5"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "does not exist" ]]
}

@test "import - empty or invalid source file" {
    create_test_file "empty.md5" ""
    
    run run_lunacopy_with_input "y" "import" "empty.md5"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "appears to be empty" ]]
    
    # Verify original file was restored
    [ -f "empty.md5" ]
    [ ! -f "empty.md5.backup" ]
}

# Test invalid choice handling
@test "hash - invalid hash method choice" {
    create_test_file "test.txt" "content"
    
    run run_lunacopy_with_input "3" "hash" "test.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid choice" ]]
}

@test "verify directory - invalid hash method choice" {
    create_test_directory "testdir"
    
    run run_lunacopy_with_input "3" "verify" "testdir"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid choice" ]]
}

@test "hash directory - invalid existing file choice" {
    create_test_directory "testdir"
    
    # Create initial hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Invalid choice
    run run_lunacopy_with_input "1\n4" "hash" "testdir"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid choice" ]]
}

# Test edge cases with special characters in filenames
@test "hash file with spaces in name" {
    create_test_file "test file.txt" "content"
    
    run run_lunacopy_with_input "1" "hash" "test file.txt"
    [ "$status" -eq 0 ]
    
    # Verify hash file was created
    [ -f "test file.txt.md5" ]
    
    # Verify verification works
    run "$LUNACOPY_SCRIPT" "verify" "test file.txt.md5"
    [ "$status" -eq 0 ]
}

@test "hash directory with files containing special characters" {
    mkdir -p "testdir"
    create_test_file "testdir/file with spaces.txt" "content1"
    create_test_file "testdir/file-with-dashes.txt" "content2"
    create_test_file "testdir/file_with_underscores.txt" "content3"
    
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Verify hash file contains all files
    local line_count=$(count_lines "testdir/testdir.md5")
    [ "$line_count" -eq 3 ]
    
    # Verify verification works
    run run_lunacopy_with_input "1" "verify" "testdir"
    [ "$status" -eq 0 ]
}

# Test relative path handling
@test "verify relative paths are handled correctly" {
    create_test_directory "testdir"
    
    # Create hash file
    run run_lunacopy_with_input "1" "hash" "testdir"
    [ "$status" -eq 0 ]
    
    # Check that paths in hash file are relative (no leading ./)
    run grep -v "^[a-f0-9]*  \\./" "testdir/testdir.md5"
    [ "$status" -eq 0 ]
    
    # All paths should be relative without ./
    while IFS= read -r line; do
        local filepath=$(echo "$line" | cut -d' ' -f3-)
        [[ ! "$filepath" =~ ^\.\/ ]]
    done < "testdir/testdir.md5"
}
