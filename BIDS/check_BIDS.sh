#!/bin/bash

# BIDS Structure Validation Script
# Validates that each subject (sub-001 to sub-025) has exactly the expected files

BIDS_DIR="/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/BIDS"
ERROR_COUNT=0
MISSING_FILES=()
EXTRA_FILES=()

# Define expected files for each folder type
declare -a ANAT_FILES=(
    "_part-mag_MEGRE.json"
    "_part-mag_MEGRE.nii.gz"
    "_part-phase_MEGRE.json"
    "_part-phase_MEGRE.nii.gz"
    "_T1w.json"
    "_T1w.nii.gz"
    "_T2w.json"
    "_T2w.nii.gz"
)

declare -a DWI_FILES=(
    "_dwi.bval"
    "_dwi.bvec"
    "_dwi.json"
    "_dwi.nii.gz"
)

declare -a FMAP_FILES=(
    "_dir-PA_run-01_epi.bval"
    "_dir-PA_run-01_epi.bvec"
    "_dir-PA_run-01_epi.nii.gz"
    "_dir-PA_run-01_epi.json"
    "_dir-PA_run-02_epi.bval"
    "_dir-PA_run-02_epi.bvec"
    "_dir-PA_run-02_epi.nii.gz"
    "_dir-PA_run-02_epi.json"
)

declare -a FUNC_FILES=(
    "_dir-AP_epi.json"
    "_dir-AP_epi.nii.gz"
    "_dir-PA_epi.json"
    "_dir-PA_epi.nii.gz"
    "_task-faces_run-01_bold.json"
    "_task-faces_run-01_bold.nii.gz"
    "_task-faces_run-02_bold.json"
    "_task-faces_run-02_bold.nii.gz"
    "_task-faces_run-03_bold.json"
    "_task-faces_run-03_bold.nii.gz"
    "_task-faces_run-04_bold.json"
    "_task-faces_run-04_bold.nii.gz"
    "_task-rest_bold.json"
    "_task-rest_bold.nii.gz"
)

# Function to check files in a folder
check_folder() {
    local subject=$1
    local folder_type=$2
    local folder_path=$3
    local expected_files=("${!4}")
    
    echo "Checking ${subject}/${folder_type}..."
    
    # Check if folder exists
    if [[ ! -d "$folder_path" ]]; then
        echo "ERROR: Missing folder $folder_path"
        ((ERROR_COUNT++))
        return
    fi
    
    # Generate expected filenames with subject prefix
    local expected_full_names=()
    for file in "${expected_files[@]}"; do
        expected_full_names+=("${subject}_ses-01${file}")
    done
    
    # Get actual files in the folder
    local actual_files=($(ls "$folder_path" 2>/dev/null | sort))
    
    # Check for missing files
    for expected_file in "${expected_full_names[@]}"; do
        if [[ ! -f "$folder_path/$expected_file" ]]; then
            echo "  MISSING: $expected_file"
            MISSING_FILES+=("$subject/$folder_type/$expected_file")
            ((ERROR_COUNT++))
        fi
    done
    
    # Check for extra files
    for actual_file in "${actual_files[@]}"; do
        local found=false
        for expected_file in "${expected_full_names[@]}"; do
            if [[ "$actual_file" == "$expected_file" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            echo "  EXTRA: $actual_file"
            EXTRA_FILES+=("$subject/$folder_type/$actual_file")
            ((ERROR_COUNT++))
        fi
    done
    
    if [[ ${#actual_files[@]} -eq ${#expected_full_names[@]} ]]; then
        local missing=0
        for expected_file in "${expected_full_names[@]}"; do
            if [[ ! -f "$folder_path/$expected_file" ]]; then
                ((missing++))
            fi
        done
        if [[ $missing -eq 0 ]]; then
            echo "  ✓ All files present and correct"
        fi
    fi
}

# Main validation loop
echo "Starting BIDS structure validation..."
echo "Base directory: $BIDS_DIR"
echo "========================================"

# Check if base directory exists
if [[ ! -d "$BIDS_DIR" ]]; then
    echo "ERROR: BIDS directory does not exist: $BIDS_DIR"
    exit 1
fi

# Loop through subjects sub-001 to sub-025
for i in $(seq -w 26 28); do
    subject=$(printf "sub-%03d" $i)
    subject_dir="$BIDS_DIR/$subject"
    session_dir="$subject_dir/ses-01"
    
    echo ""
    echo "=== Validating $subject ==="
    
    # Check if subject directory exists
    if [[ ! -d "$subject_dir" ]]; then
        echo "ERROR: Subject directory missing: $subject_dir"
        ((ERROR_COUNT++))
        continue
    fi
    
    # Check if session directory exists
    if [[ ! -d "$session_dir" ]]; then
        echo "ERROR: Session directory missing: $session_dir"
        ((ERROR_COUNT++))
        continue
    fi
    
    # Check each modality folder
    check_folder "$subject" "anat" "$session_dir/anat" ANAT_FILES[@]
    check_folder "$subject" "dwi" "$session_dir/dwi" DWI_FILES[@]
    check_folder "$subject" "fmap" "$session_dir/fmap" FMAP_FILES[@]
    check_folder "$subject" "func" "$session_dir/func" FUNC_FILES[@]
done

echo ""
echo "========================================"
echo "VALIDATION SUMMARY"
echo "========================================"

if [[ $ERROR_COUNT -eq 0 ]]; then
    echo "✓ VALIDATION PASSED: All subjects have the correct BIDS structure!"
else
    echo "✗ VALIDATION FAILED: Found $ERROR_COUNT issues"
    
    if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
        echo ""
        echo "Missing files (${#MISSING_FILES[@]}):"
        printf '%s\n' "${MISSING_FILES[@]}"
    fi
    
    if [[ ${#EXTRA_FILES[@]} -gt 0 ]]; then
        echo ""
        echo "Extra files (${#EXTRA_FILES[@]}):"
        printf '%s\n' "${EXTRA_FILES[@]}"
    fi
fi

echo ""
echo "Validation complete."
exit $ERROR_COUNT
