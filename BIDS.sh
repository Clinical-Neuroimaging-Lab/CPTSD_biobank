#!/bin/bash

# DICOM to BIDS conversion script
# Author: Generated for neuroimaging data conversion
# Requirements: dcm2bids, dcm2niix

set -e  # Exit on any error

# Configuration
RAW_DATA_DIR="/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/raw_data"
OUTPUT_DIR="/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/BIDS"
CONFIG_FILE="$OUTPUT_DIR/code/dcm2bids_config.json"

# Create BIDS directory structure
echo "Creating BIDS directory structure..."
mkdir -p "$OUTPUT_DIR"/{code,derivatives,sourcedata}
mkdir -p "$OUTPUT_DIR"/tmp_dcm2bids

# Function to check if required tools are installed
check_dependencies() {
    echo "Checking dependencies..."
    
    if ! command -v dcm2bids &> /dev/null; then
        echo "Error: dcm2bids not found. Install with: pip install dcm2bids"
        exit 1
    fi
    
    if ! command -v dcm2niix &> /dev/null; then
        echo "Error: dcm2niix not found. Install with: conda install -c conda-forge dcm2niix"
        exit 1
    fi
    
    echo "Dependencies OK"
}

# Function to create dcm2bids configuration file
create_config() {
    echo "Creating dcm2bids configuration file..."
    
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
            "suffix": "T1w",
            "criteria": {
                "SeriesDescription": "*MP3RAGE*"
            }
        },
        {
            "datatype": "anat",
            "suffix": "T2w",
            "criteria": {
                "SeriesDescription": "*T2w*SPC*"
            }
        },
        {
            "datatype": "anat",
            "suffix": "MEGRE",
            "criteria": {
                "SeriesDescription": "*QSM*",
                "ImageType": ["ORIGINAL", "PRIMARY", "M", "ND"]
            },
            "custom_entities": "part-mag"
        },
        {
            "datatype": "anat",
            "suffix": "MEGRE",
            "criteria": {
                "SeriesDescription": "*QSM*",
                "ImageType": ["ORIGINAL", "PRIMARY", "P", "ND"]
            },
            "custom_entities": "part-phase"
        },
        {
            "datatype": "func",
            "suffix": "bold",
            "criteria": {
                "SeriesDescription": "*REST*SMS*"
            },
            "custom_entities": "task-rest"
        },
        {
            "datatype": "func",
            "suffix": "bold",
            "criteria": {
                "SeriesDescription": "*sms3*"
            },
            "custom_entities": "task-faces"
        },
        {
            "datatype": "func",
            "suffix": "epi",
            "criteria": {
                "SeriesDescription": "*FM_ep2dse_AP*"
            },
            "custom_entities": "dir-AP"
        },
        {
            "datatype": "func",
            "suffix": "epi",
            "criteria": {
                "SeriesDescription": "*FM_ep2dse_PA*"
            },
            "custom_entities": "dir-PA"
        },
        {
            "datatype": "dwi",
            "suffix": "dwi",
            "criteria": {
                "SeriesDescription": "*ep2d_diff_122*"
            }
        },
        {
            "datatype": "fmap",
            "suffix": "epi",
            "criteria": {
                "SeriesDescription": "*ep2d_diff_B0_P-A*"
            },
            "custom_entities": "dir-PA"
        }
    ]
}
EOF

    echo "Configuration file created: $CONFIG_FILE"
}

# Function to create dataset_description.json
create_dataset_description() {
    echo "Creating dataset_description.json..."
    
    cat > "$OUTPUT_DIR/dataset_description.json" << EOF
{
    "Name": "Neuroimaging Study Dataset",
    "BIDSVersion": "1.8.0",
    "DatasetType": "raw",
    "License": "n/a",
    "Authors": [
        "Your Name"
    ],
    "Acknowledgements": "",
    "HowToAcknowledge": "",
    "Funding": [
        ""
    ],
    "EthicsApprovals": [
        ""
    ],
    "ReferencesAndLinks": [
        ""
    ],
    "DatasetDOI": ""
}
EOF
}

# Function to create participants.tsv
create_participants_file() {
    echo "Creating participants.tsv..."
    
    echo -e "participant_id\tage\tsex\tgroup" > "$OUTPUT_DIR/participants.tsv"
    
    for sub in $(seq -f "%03g" 1 25); do
        echo -e "sub-${sub}\tn/a\tn/a\tn/a" >> "$OUTPUT_DIR/participants.tsv"
    done
}

# Function to process a single subject
process_subject() {
    local sub_num=$1
    local sub_id=$(printf "sub-%03d" "$sub_num")
    local sub_dir="$RAW_DATA_DIR/sub-$(printf "%03d" "$sub_num")"
    
    echo "Processing $sub_id..."
    
    if [[ ! -d "$sub_dir" ]]; then
        echo "Warning: Directory $sub_dir not found, skipping..."
        return
    fi
    
    # Run dcm2bids for this subject
    dcm2bids -d "$sub_dir" \
             -p $(printf "%03d" "$sub_num") \
             -s "01" \
             -c "$CONFIG_FILE" \
             -o "$OUTPUT_DIR" \
             --force_dcm2bids \
             --clobber
    
    echo "Completed processing $sub_id"
}

# Main execution
main() {
    echo "Starting DICOM to BIDS conversion..."
    echo "Input directory: $RAW_DATA_DIR"
    echo "Output directory: $OUTPUT_DIR"
    
    # Check dependencies
    check_dependencies
    
    # Create configuration and BIDS files
    create_config
    create_dataset_description
    create_participants_file
    
    # Process subjects
    echo "Processing subjects 001-025..."
    
    for sub_num in {1..25}; do
        process_subject "$sub_num"
    done
    
    # Clean up temporary files
    echo "Cleaning up temporary files..."
    rm -rf "$OUTPUT_DIR"/tmp_dcm2bids
    
    # Run BIDS validator (if available)
    if command -v bids-validator &> /dev/null; then
        echo "Running BIDS validator..."
        bids-validator "$OUTPUT_DIR"
    else
        echo "BIDS validator not found. Install with: npm install -g bids-validator"
        echo "You can validate your dataset later at: https://bids-standard.github.io/bids-validator/"
    fi
    
    echo "DICOM to BIDS conversion completed!"
    echo "Output directory: $OUTPUT_DIR"
}

# Run the script
main "$@"
