%%-----------------------------------------------------------------------%%
%  Authors: M.A. Cloos [1], A. York [1], L.K.L. Oestreich [1]
%  M.Cloos@uq.edu.au
%  A.York@uq.edu.au
%  L.Oestreich@uq.edu.au
%  Date: 2021 February
%  Updated: 2025 September 
%  [1] University of Queensland, https://cai.centre.uq.edu.au
%%-----------------------------------------------------------------------%%
clear all; close all; clc;

%%-----------------------------------------------------------------------%%
% Settings:
%%-----------------------------------------------------------------------%%
beta = 10000;
basepath = '/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/raw_data';
participants = 12:25;  % Adjust range as needed

%%-----------------------------------------------------------------------%%
%% Loop over participants
%%-----------------------------------------------------------------------%%
for participant = participants
    % Format participant ID
    participant_id = sprintf('sub-%03d', participant);
    participant_path = fullfile(basepath, participant_id);
    
    fprintf('Processing %s...\n', participant_id);
    
    % Check if participant folder exists
    if ~exist(participant_path, 'dir')
        fprintf('  Skipping %s - folder not found\n', participant_id);
        continue;
    end
    
    % Check if already processed
    output_path = fullfile(participant_path, 'MP2RAGE_UNIDEN');
    if exist(output_path, 'dir')
        fprintf('  Skipping %s - already processed (MP2RAGE_UNIDEN exists)\n', participant_id);
        continue;
    end
    
    % Find MP2RAGE folders using wildcards
    inv1_folders = dir(fullfile(participant_path, 'MP2RAGE_*_INV1_*'));
    inv2_folders = dir(fullfile(participant_path, 'MP2RAGE_*_INV2_*'));
    uni_folders = dir(fullfile(participant_path, 'MP2RAGE_*_UNI_*'));
    
    % Filter out already processed folders
    inv1_folders = inv1_folders(~contains({inv1_folders.name}, 'denoised'));
    inv2_folders = inv2_folders(~contains({inv2_folders.name}, 'denoised'));
    uni_folders = uni_folders(~contains({uni_folders.name}, 'denoised'));
    
    fprintf('  Found %d INV1, %d INV2, %d UNI folders\n', length(inv1_folders), length(inv2_folders), length(uni_folders));
    
    % Check if we have all three types
    if isempty(inv1_folders) || isempty(inv2_folders) || isempty(uni_folders)
        fprintf('  Skipping %s - missing MP2RAGE folders\n', participant_id);
        continue;
    end
    
    % Assume we're processing the first matching set
    inv1_folder = inv1_folders(1);
    inv2_folder = inv2_folders(1);
    uni_folder = uni_folders(1);
    
    fprintf('  Using folders:\n');
    fprintf('    INV1: %s\n', inv1_folder.name);
    fprintf('    INV2: %s\n', inv2_folder.name);
    fprintf('    UNI:  %s\n', uni_folder.name);
    
    % Find DICOM files in each folder
    inv1_files = dir(fullfile(participant_path, inv1_folder.name, '*.dcm'));
    inv2_files = dir(fullfile(participant_path, inv2_folder.name, '*.dcm'));
    uni_files = dir(fullfile(participant_path, uni_folder.name, '*.dcm'));
    
    n1 = length(inv1_files);
    n2 = length(inv2_files);
    n3 = length(uni_files);
    
    fprintf('  DICOM file counts: INV1=%d, INV2=%d, UNI=%d\n', n1, n2, n3);
    
    if n1 == 0 || n2 == 0 || n3 == 0
        fprintf('  Skipping %s - no DICOM files found\n', participant_id);
        continue;
    end
    
    % Check file sizes to determine format (3D vs 4D)
    file1_info = dir(fullfile(participant_path, inv1_folder.name, inv1_files(1).name));
    file2_info = dir(fullfile(participant_path, inv2_folder.name, inv2_files(1).name));
    file3_info = dir(fullfile(participant_path, uni_folder.name, uni_files(1).name));
    
    size1_mb = file1_info.bytes / (1024*1024);
    size2_mb = file2_info.bytes / (1024*1024);
    size3_mb = file3_info.bytes / (1024*1024);
    
    fprintf('  File sizes: INV1=%.1fMB, INV2=%.1fMB, UNI=%.1fMB\n', size1_mb, size2_mb, size3_mb);
    
    % Determine processing strategy
    if n1 == 1 && n2 == 1 && n3 == 1 && max([size1_mb, size2_mb, size3_mb]) > 10
        format_type = '4D';
        fprintf('  Detected: 4D volume format\n');
    elseif n1 == n2 && n2 == n3
        format_type = '3D_matched';
        fprintf('  Detected: Multiple 3D images (matched counts)\n');
    else
        format_type = '3D_mismatched';
        min_files = min([n1, n2, n3]);
        fprintf('  Detected: Multiple 3D images (mismatched - will use first %d)\n', min_files);
    end
    
    %% Load images based on format
    try
        if strcmp(format_type, '4D')
            % Load single 4D volumes
            fprintf('  Loading 4D volumes...\n');
            im1_temp = dicomread(fullfile(participant_path, inv1_folder.name, inv1_files(1).name));
            im2_temp = dicomread(fullfile(participant_path, inv2_folder.name, inv2_files(1).name));
            im3_temp = dicomread(fullfile(participant_path, uni_folder.name, uni_files(1).name));
            
            % Squeeze to remove singleton dimensions
            im1 = squeeze(im1_temp);
            im2 = squeeze(im2_temp);
            im3 = squeeze(im3_temp);
            
            nP = size(im1, 3);
            fprintf('    Loaded %d slices from 4D volumes\n', nP);
            
        else
            % Load multiple 3D images
            if strcmp(format_type, '3D_mismatched')
                nP = min([n1, n2, n3]);
            else
                nP = n1;
            end
            
            fprintf('  Loading %d 3D images...\n', nP);
            
            % Read first image to get dimensions
            temp_img = dicomread(fullfile(participant_path, inv1_folder.name, inv1_files(1).name));
            temp_img = squeeze(temp_img);
            if ndims(temp_img) == 2
                [nR, nL] = size(temp_img);
                nSlices = 1;
            else
                [nR, nL, nSlices] = size(temp_img);
            end
            
            % Initialize arrays
            im1 = zeros(nR, nL, nP * nSlices);
            im2 = zeros(nR, nL, nP * nSlices);
            im3 = zeros(nR, nL, nP * nSlices);
            
            % Load all images
            slice_idx = 1;
            for ii = 1:nP
                temp1 = squeeze(dicomread(fullfile(participant_path, inv1_folder.name, inv1_files(ii).name)));
                temp2 = squeeze(dicomread(fullfile(participant_path, inv2_folder.name, inv2_files(ii).name)));
                temp3 = squeeze(dicomread(fullfile(participant_path, uni_folder.name, uni_files(ii).name)));
                
                if ndims(temp1) == 2
                    im1(:, :, slice_idx) = temp1;
                    im2(:, :, slice_idx) = temp2;
                    im3(:, :, slice_idx) = temp3;
                    slice_idx = slice_idx + 1;
                else
                    for s = 1:size(temp1, 3)
                        im1(:, :, slice_idx) = temp1(:, :, s);
                        im2(:, :, slice_idx) = temp2(:, :, s);
                        im3(:, :, slice_idx) = temp3(:, :, s);
                        slice_idx = slice_idx + 1;
                    end
                end
            end
            
            % Update total slice count
            nP = slice_idx - 1;
            im1 = im1(:, :, 1:nP);
            im2 = im2(:, :, 1:nP);
            im3 = im3(:, :, 1:nP);
            
            fprintf('    Loaded %d total slices from 3D images\n', nP);
        end
        
    catch ME
        fprintf('  Error loading images for %s: %s\n', participant_id, ME.message);
        continue;
    end
    
    %% Apply denoising algorithm
    fprintf('  Applying denoising algorithm...\n');
    im4 = im3 .* (im1.^2 + im2.^2);
    im5 = (im4 + beta) ./ ((im1.^2 + im2.^2) + 2 * beta);
    
    %% Create output directory and write DICOM files
    if ~exist(output_path, 'dir')
        mkdir(output_path);
    end
    
    fprintf('  Writing %d denoised DICOM files...\n', nP);
    
    % Get metadata from original UNI images
    if strcmp(format_type, '4D')
        template_metadata = dicominfo(fullfile(participant_path, uni_folder.name, uni_files(1).name));
    else
        template_metadata = dicominfo(fullfile(participant_path, uni_folder.name, uni_files(1).name));
    end
    
    % Write denoised DICOM files
    for ii = 1:nP
        try
            % Create metadata for this slice
            metadata = template_metadata;
            
            % Clean problematic fields
            fields_to_remove = {'Group', 'Element', 'VR', 'Length', 'Data'};
            for field_idx = 1:length(fields_to_remove)
                if isfield(metadata, fields_to_remove{field_idx})
                    metadata = rmfield(metadata, fields_to_remove{field_idx});
                end
            end
            
            % Update metadata
            try
                metadata.SeriesDescription = [metadata.SeriesDescription '_DEN'];
            catch
                metadata.SeriesDescription = 'MP2RAGE_DENOISED';
            end
            metadata.SeriesNumber = 195;
            metadata.InstanceNumber = ii;
            
            % Generate new UIDs
            try
                SOPInstanceUID = dicomuid;
                metadata.SOPInstanceUID = SOPInstanceUID;
                metadata.MediaStorageSOPInstanceUID = SOPInstanceUID;
                metadata.SeriesInstanceUID = dicomuid;
            catch
                % Skip UID updates if they fail
            end
            
            % Write DICOM file
            dicom_filename = fullfile(output_path, sprintf('denoised_%03d.dcm', ii));
            
            try
                dicomwrite(uint16(squeeze(im5(:, :, ii))), dicom_filename, metadata);
            catch
                % Fallback with minimal metadata
                minimal_metadata = struct();
                minimal_metadata.SeriesDescription = 'MP2RAGE_DENOISED';
                minimal_metadata.SeriesNumber = 195;
                minimal_metadata.InstanceNumber = ii;
                dicomwrite(uint16(squeeze(im5(:, :, ii))), dicom_filename, minimal_metadata);
            end
            
        catch ME
            fprintf('    Warning: Failed to write slice %d: %s\n', ii, ME.message);
        end
    end
    
    %% Create comparison figure
    middle_slice = round(nP/2);
    try
        figure;
        subplot(1, 2, 1);
        imshow(im3(:, :, middle_slice), [0, 4000]);
        title(sprintf('%s - Original (slice %d)', participant_id, middle_slice));
        subplot(1, 2, 2);
        imshow(im5(:, :, middle_slice), [0, 4000]);
        title(sprintf('%s - Denoised (slice %d)', participant_id, middle_slice));
        
        % Save comparison
        saveas(gcf, fullfile(output_path, sprintf('%s_comparison.png', participant_id)));
        close(gcf);
    catch
        fprintf('    Warning: Could not create comparison figure\n');
    end
    
    fprintf('  Completed %s - processed %d slices\n', participant_id, nP);
    
end

fprintf('All participants processed!\n');