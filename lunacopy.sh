#!/bin/bash

# Version 1.0.2 (Bug fixes applied)
# MIT License
# Copyright 2025 Ray Doll, https://github.com/sheafdynamics/
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# If any command fails, the script will exit immediately.
set -e

# Debugging purposes
#set -x

# Trap any error and print a message indicating on which line the error occurred.
trap 'echo "Error at line $LINENO"' ERR

# A function named 'usage' which prints out how to use this script.
function usage {
    echo "Usage: $0 [hash|verify|import] path"
    exit 1
}

# Check if the number of arguments provided to the script is not equal to 2.
# If not, call the 'usage' function, printout how to use this script.
if [ "$#" -ne 2 ]; then
    usage
fi

# Assign the first argument to a variable named 'action'.
action="$1"
# Assign the second argument to a variable named 'path'.
path="$2"

# Validate that the path exists for hash and verify operations
if [[ "$action" == "hash" || "$action" == "verify" ]]; then
    if [[ ! -e "$path" ]]; then
        echo "Error: Path '$path' does not exist."
        exit 1
    fi
fi

# Extract the base name of the path (i.e., the file or directory name) and assign to 'name'.
name=$(basename "$path")

# Based on the value of 'action', perform different operations.
case $action in
    hash)
        # If the action is 'hash', the script will calculate file hashes.
        # Prompt the user to select a hashing method for a new hashing operation.
        echo "Choose a hashing method:"
        echo "[1] md5"
        echo "[2] sha256"
        read -p "Enter your choice (1/2): " choice

        # Based on the user's choice, set the hash_command and ext variables.
        case $choice in
            1)
                hash_command="md5sum"
                ext="md5"
                ;;
            2)
                hash_command="sha256sum"
                ext="sha256"
                ;;
            *)
                # If the user's choice is neither 1 nor 2, exit with an error.
                echo "Invalid choice. Exiting."
                exit 1
                ;;
        esac

        # Check if the provided path is a directory.
        if [[ -d "$path" ]]; then
            # Check if a hash file already exists in the directory.
            if [[ -e "$path"/"${name}.$ext" ]]; then
                # If it does, provide options to the user.
                echo "Testfile \"${name}.$ext\" already exists in the directory."
                echo "[1] Hash only new files, add them to existing testfile \"${name}.$ext\" (faster, non-destructive)."
                echo "[2] Re-hash everything and overwrite testfile \"${name}.$ext\" with new hashes (slower, situational)."
                echo "[3] Exit without modifying existing testfile \"${name}.$ext\"."
                read -p "Enter your choice (1/2/3): " choice || true

                case $choice in
                    1)
                        # Option to hash only new files.
                        # Initialize empty variables.
                        new_file_hashes=
                        new_files_to_add=()

                        # Loop over each file in the directory.
                        while IFS= read -r -d '' file; do
                            # Get relative path from the directory being hashed
                            relative_file="${file#$path/}"
                            
                            # Check if the file already has a hash in the testfile.
                            # Fixed: Use proper escaping and look for the relative path
                            if grep -qF -- "$relative_file" "$path/${name}.$ext" 2>/dev/null; then
                                continue
                            fi

                            # Calculate the hash for the file.
                            hash=$($hash_command "$file" | awk '{print $1}')

                            # Append the hash and relative filename to the new_file_hashes variable.
                            new_file_hashes+="${hash}  ${relative_file}"$'\n'
                            new_files_to_add+=("$relative_file")

                        # This syntax continues the loop for all files in the directory.
                        done < <(find "$path" -type f -not -name "${name}.$ext" -print0)

                        # If there are new files to be added, add them to the testfile.
                        if [ ${#new_files_to_add[@]} -gt 0 ]; then
                            echo "Files not present in the testfile:"
                            for new_file in "${new_files_to_add[@]}"; do
                                echo "  - $new_file"
                            done
                            new_file_hashes="${new_file_hashes%$'\n'}"
                            echo "$new_file_hashes" >> "$path"/"${name}.$ext"
                            echo "New files have been hashed and added to the existing testfile."
                            exit 0
                        else
                            # If no new files found, inform the user and exit.
                            echo "No new files have been detected not already in the testfile."
                            echo "Testfile update is not needed."
                            echo "Exited."
                            exit 0
                        fi
                        ;;
                    2)
                        # Option to re-hash everything anew.
                        # Confirm with the user.
                        read -p "Are you sure you want to re-hash all the files? This will overwrite the existing testfile. (y/n) " verify_choice || true
                        if [[ "$verify_choice" != "y" ]]; then
                            echo "Operation cancelled by the user."
                            exit 1
                        fi
                        # Continue to create new hash file (fall through)
                        ;;
                    3)
                        # Option to exit without modifying the testfile.
                        echo "Exited without modifying the testfile."
                        exit 0
                        ;;
                    *)
                        # If the user's choice is not recognized, exit with an error.
                        echo "Invalid choice. Operation cancelled."
                        exit 1
                        ;;
                esac
            fi
            
            # Hash the directory content and create a new testfile with relative paths
            # Change to the directory to ensure relative paths in output
            (cd "$path" && find . -type f -not -name "${name}.$ext" -exec $hash_command {} + | sed 's|^\([a-f0-9]*\)  \./|\1  |') > "$path"/"${name}.$ext"
            echo "New testfile \"${name}.$ext\" written successfully."
        else
            # If the provided path is a file.
            # Check if a hash file already exists for the file.
            if [[ -e "${path}.$ext" ]]; then
                echo "Testfile \"${name}.$ext\" already exists."
                read -p "Do you wish to overwrite it with a new hash? (y/n) " response || true
                if [[ "$response" != "y" ]]; then
                    echo "Operation cancelled by the user."
                    exit 1
                fi
            fi

            # Calculate the hash for the file and create or overwrite the testfile.
            # Use only the filename, not the full path for single file hashing
            (cd "$(dirname "$path")" && $hash_command "$(basename "$path")") > "${path}.$ext"
            echo "New testfile \"${name}.$ext\" written successfully."
        fi
        ;;

    verify)
        # If the action is 'verify', the script will verify the file hashes against the testfile.

        # Get the current Unix timestamp to name the error log.
        date=$(date +%s)

        # Check if the provided path is a directory.
        if [[ -d "$path" ]]; then

            # Prompt the user to select a hashing method for verification.
            echo "Choose a hashing method to verify:"
            echo "[1] md5"
            echo "[2] sha256"
            read -p "Enter your choice (1/2): " choice

            # Based on the user's choice, set the ext and hash_command variables.
            case $choice in
                1)
                    ext="md5"
                    hash_command="md5sum"
                    ;;
                2)
                    ext="sha256"
                    hash_command="sha256sum"
                    ;;
                *)
                    # If the user's choice is neither 1 nor 2, exit with an error.
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac

            # Check if the testfile exists.
            if [[ ! -f "$path/$name.$ext" ]]; then
                echo "Error: Testfile \"$path/$name.$ext\" not found."
                exit 1
            fi

            # Verify the file hashes against the testfile and capture any errors.
            # Change to the directory to handle relative paths correctly
            errors=$(cd "$path" && $hash_command -c "$name.$ext" 2>&1 | grep -v ': OK$' 2>/dev/null || true)
        else
            # If the provided path is a file, extract its extension.
            ext="${name##*.}"

            # Based on the file extension, set the hash_command.
            case $ext in
                md5)
                    hash_command="md5sum"
                    ;;
                sha256)
                    hash_command="sha256sum"
                    ;;
                *)
                    # If the file extension is not recognized, call the 'usage' function and exit with an error.
                    usage
                    exit 1
                    ;;
            esac

            # Check if the testfile exists
            if [[ ! -f "$path" ]]; then
                echo "Error: Testfile \"$path\" not found."
                exit 1
            fi

            # Verify the file hash against the testfile and capture any errors.
            # Change to the directory containing the testfile to handle relative paths
            errors=$(cd "$(dirname "$path")" && $hash_command -c "$(basename "$path")" 2>&1 | grep -v ': OK$' 2>/dev/null || true)
        fi

        # Check if there were any errors during verification.
        if [[ -z "$errors" ]]; then
            echo "All files verified successfully."
            exit 0
        else
            # If there were errors, write them to an error log.
            if [[ -d "$path" ]]; then
                error_log="${path}/${name}.${ext}.${date}.error.log"
            else
                error_log="${path}.${date}.error.log"
            fi
            echo "$errors" > "$error_log"
            echo "Verification errors detected. See the error log at: $error_log"
            exit 1
        fi
        ;;

    import)
        # If the action is 'import', the script will attempt to convert a popular closed-source testfile format to an open LunaCopy format.

        # Check if the file exists first
        if [[ ! -f "$path" ]]; then
            echo "Error: File '$path' does not exist."
            exit 1
        fi

        # Extract the extension from the provided path
        ext="${path##*.}"

        # Check if it's one of the valid extensions
        if [[ "$ext" != "md5" && "$ext" != "sha256" ]]; then
            echo "Error: Invalid extension. Only .md5, or .sha256 are allowed."
            exit 1
        fi

        # Prompt the user for confirmation.
        read -p "This function will attempt to convert a popular closed-source $ext testfile into an open LunaCopy format. Original will be renamed \"filename.$ext.backup\" without any changes, and a new one will be created with the name of the original. Would you like to proceed? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            echo "Operation cancelled by the user."
            exit 1
        fi

        # Rename the original file for backup
        mv "$path" "${path}.backup"

        # Convert closed-source format to an open LunaCopy format
        # Enhanced awk script to handle more edge cases
        awk '
        NR > 3 {
            # Skip empty lines
            if (NF == 0) next
            
            # Extract hash (first field)
            hash = $1
            
            # Remove hash from the line to get filename
            $1 = ""
            filename = substr($0, 2)  # Remove leading space
            
            # Convert backslashes to forward slashes
            gsub(/\\/, "/", filename)
            
            # Remove leading asterisk if present
            gsub(/^\*/, "", filename)
            
            # Skip if hash or filename is empty
            if (length(hash) == 0 || length(filename) == 0) next
            
            # Print in LunaCopy format with lowercase hash
            print tolower(hash) "  " filename
        }' "${path}.backup" > "$path"

        # Verify the conversion was successful
        if [[ ! -s "$path" ]]; then
            echo "Warning: The converted file appears to be empty. Please check the original format."
            mv "${path}.backup" "$path"
            echo "Restoration completed. Original file restored."
            exit 1
        fi

        # Inform the user that the conversion is complete.
        echo "Conversion complete. Original has been renamed to \"${path}.backup\" and a new LunaCopy testfile file has been created as \"$path\"."
        ;;
    *)
        # If the action is not recognized, call the 'usage' function.
        usage
        ;;
esac
