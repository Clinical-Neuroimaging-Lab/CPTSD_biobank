#!/bin/bash

# DICOM to NIfTI Conversion Script for MP2RAGE data
# Converts sub-017 through sub-029

# Configuration
BASE_DIR="/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/raw_data"
START_PARTICIPANT=16
END_PARTICIPANT=29

echo "=== MP2RAGE DICOM to NIfTI Conversion ==="
echo "Processing participants sub-$(printf "%03d" $START_PARTICIPANT) to sub-$(printf "%03d" $END_PARTICIPANT)"
echo "Base directory: $BASE_DIR"
echo ""

# Check if dcm2niix is available
if ! command -v dcm2niix &> /dev/null; then
    echo "ERROR: dcm2niix not found. Please install dcm2niix first."
    echo "  macOS: brew install dcm2niix"
    echo "  Ubuntu: sudo apt install dcm2niix"
    exit 1
fi

# Loop through participants
for participant_num in $(seq $START_PARTICIPANT $END_PARTICIPANT); do
    # Format participant ID
    participant_id=$(printf "sub-%03d" $participant_num)
    participant_dir="$BASE_DIR/$participant_id"
    
    echo "Processing $participant_id..."
    
    # Check if participant directory exists
    if [ ! -d "$participant_dir" ]; then
        echo "  Skipping $participant_id - directory not found"
        continue
    fi
    
    # Change to participant directory
    cd "$participant_dir"
    
    # Find MP2RAGE folders
    inv1_folders=(MP2RAGE_*_INV1_*)
    inv2_folders=(MP2RAGE_*_INV2_*)
    uni_folders=(MP2RAGE_*_UNI_*)
    
    # Check if folders exist (handle case where glob doesn't match)
    if [ ! -d "${inv1_folders[0]}" ] || [ ! -d "${inv2_folders[0]}" ] || [ ! -d "${uni_folders[0]}" ]; then
        echo "  Skipping $participant_id - MP2RAGE folders not found"
        echo "    Looking for: MP2RAGE_*_INV1_*, MP2RAGE_*_INV2_*, MP2RAGE_*_UNI_*"
        continue
    fi
    
    echo "  Found MP2RAGE folders:"
    printf "    INV1: %s\n" "${inv1_folders[@]}"
    printf "    INV2: %s\n" "${inv2_folders[@]}"
    printf "    UNI:  %s\n" "${uni_folders[@]}"
    
    # Process each set of folders
    num_sets=${#inv1_folders[@]}
    
    for ((set_idx=0; set_idx<num_sets; set_idx++)); do
        inv1_folder="${inv1_folders[$set_idx]}"
        inv2_folder="${inv2_folders[$set_idx]}"
        uni_folder="${uni_folders[$set_idx]}"
        
        # Extract set identifier if multiple sets (optional)
        if [ $num_sets -gt 1 ]; then
            set_suffix="_set$((set_idx+1))"
        else
            set_suffix=""
        fi
        
        echo "  Converting set $((set_idx+1))/$num_sets..."
        
        # Check if already converted
        if [ -f "${participant_id}${set_suffix}_inv1.nii.gz" ] && \
           [ -f "${participant_id}${set_suffix}_inv2.nii.gz" ] && \
           [ -f "${participant_id}${set_suffix}_uni.nii.gz" ]; then
            echo "    Skipping set $((set_idx+1)) - already converted"
            continue
        fi
        
        # Convert INV1
        echo "    Converting INV1..."
        dcm2niix -f "${participant_id}${set_suffix}_inv1" -o . -z y -b y "$inv1_folder" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "      ✓ INV1 converted successfully"
        else
            echo "      ✗ INV1 conversion failed"
        fi
        
        # Convert INV2
        echo "    Converting INV2..."
        dcm2niix -f "${participant_id}${set_suffix}_inv2" -o . -z y -b y "$inv2_folder" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "      ✓ INV2 converted successfully"
        else
            echo "      ✗ INV2 conversion failed"
        fi
        
        # Convert UNI
        echo "    Converting UNI..."
        dcm2niix -f "${participant_id}${set_suffix}_uni" -o . -z y -b y "$uni_folder" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "      ✓ UNI converted successfully"
        else
            echo "      ✗ UNI conversion failed"
        fi
        
        # Verify all three files were created
        if [ -f "${participant_id}${set_suffix}_inv1.nii.gz" ] && \
           [ -f "${participant_id}${set_suffix}_inv2.nii.gz" ] && \
           [ -f "${participant_id}${set_suffix}_uni.nii.gz" ]; then
            echo "      ✓ Set $((set_idx+1)) conversion complete"
            
            # Display file sizes for verification
            echo "      File sizes:"
            ls -lh "${participant_id}${set_suffix}_inv1.nii.gz" | awk '{print "        INV1: " $5}'
            ls -lh "${participant_id}${set_suffix}_inv2.nii.gz" | awk '{print "        INV2: " $5}'
            ls -lh "${participant_id}${set_suffix}_uni.nii.gz" | awk '{print "        UNI:  " $5}'
        else
            echo "      ✗ Set $((set_idx+1)) conversion incomplete"
        fi
    done
    
    echo "  Completed $participant_id"
    echo ""
done

echo "=== Conversion Summary ==="
echo "Checking final results..."

# Summary of converted files
total_participants=0
successful_participants=0

for participant_num in $(seq $START_PARTICIPANT $END_PARTICIPANT); do
    participant_id=$(printf "sub-%03d" $participant_num)
    participant_dir="$BASE_DIR/$participant_id"
    
    if [ -d "$participant_dir" ]; then
        total_participants=$((total_participants + 1))
        
        cd "$participant_dir"
        nii_files=(${participant_id}*_uni.nii.gz)
        
        if [ -f "${nii_files[0]}" ]; then
            successful_participants=$((successful_participants + 1))
            echo "$participant_id: ✓ (${#nii_files[@]} sets)"
        else
            echo "$participant_id: ✗"
        fi
    fi
done

echo ""
echo "Conversion complete: $successful_participants/$total_participants participants"
echo ""
echo "Next step: Update the MATLAB script file patterns to match your NIfTI naming:"
echo "  inv1_pattern = '*_inv1*.nii*';"
echo "  inv2_pattern = '*_inv2*.nii*';"
echo "  uni_pattern = '*_uni*.nii*';"
