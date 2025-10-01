#!/bin/bash

# Full DICOM to BIDS conversion for all subjects
# Based on working single-subject test configuration

set -e

# Configuration
RAW_DATA_DIR="/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/raw_data"
OUTPUT_DIR="/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/BIDS"
CONFIG_FILE="$OUTPUT_DIR/code/dcm2bids_config.json"

echo "=== FULL DICOM TO BIDS CONVERSION ==="
echo "Processing subjects 001-025"
echo "Input directory: $RAW_DATA_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

read -p "Are you sure you want to proceed with full conversion? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Clean and create BIDS directory
if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Removing existing BIDS directory..."
    rm -rf "$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"/{code,derivatives,sourcedata}
mkdir -p "$OUTPUT_DIR"/tmp_dcm2bids

# Function to create working configuration
create_working_config() {
    echo "Creating working configuration with wildcards..."
    
    cat > "$CONFIG_FILE" << 'EOF'
{
    "descriptions": [
        {
            "datatype": "anat",
            "suffix": "T1w",
            "criteria": {
                "SeriesDescription": "*MP2RAGE*"
            }
        },
        {
            "datatype": "anat",
            "suffix": "T2w",
            "criteria": {
                "SeriesDescription": "*T2w*"
            }
        },
        {
            "datatype": "anat",
            "suffix": "MEGRE",
            "criteria": {
                "SeriesDescription": "*QSM*",
                "ImageType": ["ORIGINAL", "PRIMARY", "M", "NONE", "MAGNITUDE"]
            },
            "custom_entities": "part-mag"
        },
        {
            "datatype": "anat",
            "suffix": "MEGRE",
            "criteria": {
                "SeriesDescription": "*QSM*",
                "ImageType": ["ORIGINAL", "PRIMARY", "P", "NONE", "PHASE"]
            },
            "custom_entities": "part-phase"
        },
        {
            "datatype": "func",
            "suffix": "bold",
            "criteria": {
                "SeriesDescription": "ep2d_REST_SMS5_A-P"
            },
            "custom_entities": "task-rest"
        },
        {
            "datatype": "func",
            "suffix": "bold",
            "criteria": {
                "SeriesDescription": "ep2d_sms3_R1"
            },
            "custom_entities": "task-faces_run-01"
        },
        {
            "datatype": "func",
            "suffix": "bold",
            "criteria": {
                "SeriesDescription": "ep2d_sms3_R2"
            },
            "custom_entities": "task-faces_run-02"
        },
        {
            "datatype": "func",
            "suffix": "bold",
            "criteria": {
                "SeriesDescription": "ep2d_sms3_R3"
            },
            "custom_entities": "task-faces_run-03"
        },
        {
            "datatype": "func",
            "suffix": "bold",
            "criteria": {
                "SeriesDescription": "ep2d_sms3_R4"
            },
            "custom_entities": "task-faces_run-04"
        },
        {
            "datatype": "func",
            "suffix": "epi",
            "criteria": {
                "SeriesDescription": "FM_ep2dse_AP"
            },
            "custom_entities": "dir-AP"
        },
        {
            "datatype": "func",
            "suffix": "epi",
            "criteria": {
                "SeriesDescription": "FM_ep2dse_PA"
            },
            "custom_entities": "dir-PA"
        },
        {
            "datatype": "dwi",
            "suffix": "dwi",
            "criteria": {
                "SeriesDescription": "ep2d_diff_122"
            }
        },
        {
            "datatype": "fmap",
            "suffix": "epi",
            "criteria": {
                "SeriesDescription": "ep2d_diff_B0_P-A_1"
            },
            "custom_entities": "dir-PA_run-01"
        },
        {
            "datatype": "fmap",
            "suffix": "epi",
            "criteria": {
                "SeriesDescription": "ep2d_diff_B0_P-A_2"
            },
            "custom_entities": "dir-PA_run-02"
        }
    ]
}
EOF

    echo "Configuration created with working wildcards and ImageType specifications."
}

# Function to create dataset_description.json
create_dataset_description() {
    cat > "$OUTPUT_DIR/dataset_description.json" << EOF
{
    "Name": "Neuroimaging Study Dataset",
    "BIDSVersion": "1.8.0",
    "DatasetType": "raw"
}
EOF
}

# Function to process all subjects
process_all_subjects() {
    echo "Processing all subjects 001-025..."
    
    local processed_count=0
    local failed_count=0
    
    for sub_num in {1..25}; do
        local sub_id=$(printf "sub-%03d" "$sub_num")
        local sub_dir="$RAW_DATA_DIR/$sub_id"
        
        echo ""
        echo "Processing $sub_id..."
        
        if [[ ! -d "$sub_dir" ]]; then
            echo "Warning: Directory $sub_dir not found, skipping..."
            ((failed_count++))
            continue
        fi
        
        # Run dcm2bids for this subject
        if dcm2bids -d "$sub_dir" \
                   -p $(printf "%03d" "$sub_num") \
                   -s "01" \
                   -c "$CONFIG_FILE" \
                   -o "$OUTPUT_DIR" \
                   --force_dcm2bids \
                   --clobber; then
            echo "✅ Successfully processed $sub_id"
            ((processed_count++))
        else
            echo "❌ Failed to process $sub_id"
            ((failed_count++))
        fi
    done
    
    echo ""
    echo "=== PROCESSING SUMMARY ==="
    echo "Successfully processed: $processed_count subjects"
    echo "Failed: $failed_count subjects"
    echo "Total attempted: 25 subjects"
}

# Function to verify conversion results
verify_conversion_results() {
    echo ""
    echo "=== CONVERSION VERIFICATION ==="
    
    local total_subjects=0
    local t1w_count=0
    local t2w_count=0
    local qsm_count=0
    local dwi_count=0
    local func_count=0
    
    for sub_num in {1..25}; do
        local sub_id=$(printf "sub-%03d" "$sub_num")
        local sub_dir="$OUTPUT_DIR/$sub_id"
        
        if [[ -d "$sub_dir" ]]; then
            ((total_subjects++))
            
            # Check T1w
            if ls "$sub_dir"/*/anat/*T1w* 2>/dev/null | grep -q .; then
                ((t1w_count++))
            fi
            
            # Check T2w
            if ls "$sub_dir"/*/anat/*T2w* 2>/dev/null | grep -q .; then
                ((t2w_count++))
            fi
            
            # Check QSM
            if ls "$sub_dir"/*/anat/*MEGRE* 2>/dev/null | grep -q .; then
                ((qsm_count++))
            fi
            
            # Check DWI
            if ls "$sub_dir"/*/dwi/*dwi* 2>/dev/null | grep -q .; then
                ((dwi_count++))
            fi
            
            # Check functional
            if ls "$sub_dir"/*/func/*bold* 2>/dev/null | grep -q .; then
                ((func_count++))
            fi
        fi
    done
    
    echo "SUMMARY:"
    echo "Total subjects processed: $total_subjects"
    echo "T1w images: $t1w_count/$total_subjects"
    echo "T2w images: $t2w_count/$total_subjects"
    echo "QSM images: $qsm_count/$total_subjects"
    echo "DWI images: $dwi_count/$total_subjects"
    echo "Functional images: $func_count/$total_subjects"
    
    # List any subjects with missing data
    echo ""
    echo "Subjects with missing anatomical data:"
    for sub_num in {1..25}; do
        local sub_id=$(printf "sub-%03d" "$sub_num")
        local sub_dir="$OUTPUT_DIR/$sub_id"
        
        if [[ -d "$sub_dir" ]]; then
            local missing=""
            if ! ls "$sub_dir"/*/anat/*T1w* 2>/dev/null | grep -q .; then
                missing="$missing T1w"
            fi
            if ! ls "$sub_dir"/*/anat/*T2w* 2>/dev/null | grep -q .; then
                missing="$missing T2w"
            fi
            if ! ls "$sub_dir"/*/anat/*MEGRE* 2>/dev/null | grep -q .; then
                missing="$missing QSM"
            fi
            
            if [[ -n "$missing" ]]; then
                echo "  $sub_id: missing$missing"
            fi
        fi
    done
}

# Main execution
main() {
    echo "Starting full DICOM to BIDS conversion..."
    
    # Check dependencies
    if ! command -v dcm2bids &> /dev/null; then
        echo "Error: dcm2bids not found!"
        exit 1
    fi
    
    # Create configuration and BIDS structure
    create_working_config
    create_dataset_description
    
    # Process all subjects
    process_all_subjects
    
    # Clean up temporary files
    echo ""
    echo "Cleaning up temporary files..."
    rm -rf "$OUTPUT_DIR"/tmp_dcm2bids
    
    # Verify results
    verify_conversion_results
    
    # Run BIDS validator if available
    if command -v bids-validator &> /dev/null; then
        echo ""
        echo "Running BIDS validator..."
        bids-validator "$OUTPUT_DIR"
    else
        echo ""
        echo "BIDS validator not found. Install with: npm install -g bids-validator"
        echo "You can validate your dataset later at: https://bids-standard.github.io/bids-validator/"
    fi
    
    echo ""
    echo "=== CONVERSION COMPLETED ==="
    echo "Output directory: $OUTPUT_DIR"
    echo "Check the verification summary above for any issues."
}

# Run the script
main "$@"
