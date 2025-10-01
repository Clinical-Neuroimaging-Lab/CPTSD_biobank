%%-----------------------------------------------------------------------%%
%  MP2RAGE NIfTI Denoising Script
%  Authors: M.A. Cloos [1], A. York [1], L.K.L. Oestreich [1]
%  Updated for NIfTI workflow: 2025 September 
%  [1] University of Queensland, https://cai.centre.uq.edu.au
%%-----------------------------------------------------------------------%%
clear all; close all; clc;

%%-----------------------------------------------------------------------%%
% Settings:
%%-----------------------------------------------------------------------%%
beta = 10000;
basepath = '/Users/uqloestr/Library/CloudStorage/OneDrive-TheUniversityofQueensland/Desktop/raw_data';
participants = 14;  % Adjust range as needed

% NIfTI file patterns to look for (adjust these to match your converted files)
inv1_pattern = '*inv1*.nii*';  % e.g., 'sub-001_inv1.nii.gz'
inv2_pattern = '*inv2*.nii*';  % e.g., 'sub-001_inv2.nii.gz'
uni_pattern = '*uni*.nii*';    % e.g., 'sub-001_uni.nii.gz'

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
    
    % Look for NIfTI files
    inv1_files = dir(fullfile(participant_path, inv1_pattern));
    inv2_files = dir(fullfile(participant_path, inv2_pattern));
    uni_files = dir(fullfile(participant_path, uni_pattern));
    
    % Filter out already processed files
    inv1_files = inv1_files(~contains({inv1_files.name}, 'denoised'));
    inv2_files = inv2_files(~contains({inv2_files.name}, 'denoised'));
    uni_files = uni_files(~contains({uni_files.name}, 'denoised'));
    
    fprintf('  Found %d INV1, %d INV2, %d UNI NIfTI files\n', length(inv1_files), length(inv2_files), length(uni_files));
    
    % Check if we have all three types
    if isempty(inv1_files) || isempty(inv2_files) || isempty(uni_files)
        fprintf('  Skipping %s - missing NIfTI files\n', participant_id);
        fprintf('    Looking for patterns: %s, %s, %s\n', inv1_pattern, inv2_pattern, uni_pattern);
        continue;
    end
    
    % Process each matching set
    num_sets = min([length(inv1_files), length(inv2_files), length(uni_files)]);
    
    for set_idx = 1:num_sets
        inv1_file = inv1_files(set_idx);
        inv2_file = inv2_files(set_idx);
        uni_file = uni_files(set_idx);
        
        fprintf('  Processing set %d of %d:\n', set_idx, num_sets);
        fprintf('    INV1: %s\n', inv1_file.name);
        fprintf('    INV2: %s\n', inv2_file.name);
        fprintf('    UNI:  %s\n', uni_file.name);
        
        % Full file paths
        inv1_path = fullfile(participant_path, inv1_file.name);
        inv2_path = fullfile(participant_path, inv2_file.name);
        uni_path = fullfile(participant_path, uni_file.name);
        
        % Check if already processed
        [~, uni_basename, uni_ext] = fileparts(uni_file.name);
        if endsWith(uni_basename, '.nii')  % Handle .nii.gz case
            [~, uni_basename, ~] = fileparts(uni_basename);
        end
        output_filename = sprintf('%s_denoised%s', uni_basename, uni_ext);
        output_path = fullfile(participant_path, output_filename);
        
        if exist(output_path, 'file')
            fprintf('    Skipping set %d - already processed (%s exists)\n', set_idx, output_filename);
            continue;
        end
        
        %% Load NIfTI files
        try
            fprintf('    Loading NIfTI volumes...\n');
            
            % Load volumes
            V1 = niftiread(inv1_path);
            V2 = niftiread(inv2_path);
            V3 = niftiread(uni_path);
            
            % Load header info from UNI (to preserve for output)
            V3_info = niftiinfo(uni_path);
            
            % Convert to double for processing
            V1 = double(V1);
            V2 = double(V2);
            V3 = double(V3);
            
            fprintf('    Loaded volumes: %dx%dx%d\n', size(V1,1), size(V1,2), size(V1,3));
            
            % Check dimensions match
            if ~isequal(size(V1), size(V2)) || ~isequal(size(V1), size(V3))
                fprintf('    Error: Volume dimensions do not match\n');
                fprintf('      INV1: %dx%dx%d\n', size(V1,1), size(V1,2), size(V1,3));
                fprintf('      INV2: %dx%dx%d\n', size(V2,1), size(V2,2), size(V2,3));
                fprintf('      UNI:  %dx%dx%d\n', size(V3,1), size(V3,2), size(V3,3));
                continue;
            end
            
        catch ME
            fprintf('    Error loading NIfTI files: %s\n', ME.message);
            continue;
        end
        
        %% Apply MP2RAGE denoising
        fprintf('    Applying MP2RAGE denoising (beta=%.0f)...\n', beta);
        
        % Calculate sum of squares
        V1_squared = V1.^2;
        V2_squared = V2.^2;
        sum_squared = V1_squared + V2_squared;
        
        % Avoid division by zero
        sum_squared(sum_squared == 0) = eps;
        
        % Apply denoising formula
        V4 = V3 .* sum_squared;
        V5 = (V4 + beta) ./ (sum_squared + 2 * beta);
        
        % Display intensity statistics
        fprintf('    Intensity ranges:\n');
        fprintf('      Original UNI: [%.1f, %.1f], mean=%.1f\n', min(V3(:)), max(V3(:)), mean(V3(:)));
        fprintf('      Denoised:     [%.1f, %.1f], mean=%.1f\n', min(V5(:)), max(V5(:)), mean(V5(:)));
        
        %% Optional: Scale denoised to match original intensity range
        % Uncomment if you want to preserve original intensity scaling
        % V5_scaled = (V5 - min(V5(:))) ./ (max(V5(:)) - min(V5(:))) .* (max(V3(:)) - min(V3(:))) + min(V3(:));
        % V5 = V5_scaled;
        
        %% Save denoised NIfTI
        try
            fprintf('    Saving denoised volume: %s\n', output_filename);
            
            % Update header description
            V3_info.Description = [V3_info.Description, ' - MP2RAGE Denoised (beta=', num2str(beta), ')'];
            
            % Save as same data type as original (but ensure it fits)
            if strcmp(V3_info.Datatype, 'int16') || strcmp(V3_info.Datatype, 'uint16')
                % Scale to fit 16-bit range
                V5_scaled = V5 / max(V5(:)) * (2^15 - 1);  % Use int16 range
                niftiwrite(int16(V5_scaled), output_path, V3_info, 'Compressed', true);
            else
                % Keep as floating point
                niftiwrite(single(V5), output_path, V3_info, 'Compressed', true);
            end
            
            fprintf('    Successfully saved: %s\n', output_path);
            
        catch ME
            fprintf('    Error saving NIfTI: %s\n', ME.message);
            continue;
        end
        
        %% Create comparison figure
        try
            middle_slice = round(size(V3, 3) / 2);
            
            figure('Position', [100, 100, 1200, 400]);
            
            % Original
            subplot(1, 3, 1);
            imshow(V3(:, :, middle_slice), []);
            title(sprintf('%s Set%d - Original', participant_id, set_idx));
            colorbar;
            
            % Denoised
            subplot(1, 3, 2);
            imshow(V5(:, :, middle_slice), []);
            title('Denoised');
            colorbar;
            
            % Difference
            subplot(1, 3, 3);
            diff_img = V3(:, :, middle_slice) - V5(:, :, middle_slice);
            imshow(diff_img, []);
            title('Difference');
            colorbar;
            
            sgtitle(sprintf('%s Set %d - Slice %d/%d', participant_id, set_idx, middle_slice, size(V3,3)));
            
            % Save comparison
            comp_filename = sprintf('%s_set%d_comparison.png', participant_id, set_idx);
            saveas(gcf, fullfile(participant_path, comp_filename));
            close(gcf);
            
        catch
            fprintf('    Warning: Could not create comparison figure\n');
        end
        
        %% Calculate and save denoising metrics
        try
            % Calculate basic metrics
            original_std = std(V3(:));
            denoised_std = std(V5(:));
            noise_reduction = (original_std - denoised_std) / original_std * 100;
            
            correlation = corrcoef(V3(:), V5(:));
            correlation_coeff = correlation(1, 2);
            
            % Save metrics
            metrics_filename = sprintf('%s_set%d_metrics.txt', participant_id, set_idx);
            metrics_path = fullfile(participant_path, metrics_filename);
            
            fid = fopen(metrics_path, 'w');
            fprintf(fid, 'MP2RAGE Denoising Metrics - %s Set %d\n', participant_id, set_idx);
            fprintf(fid, '==========================================\n');
            fprintf(fid, 'Input files:\n');
            fprintf(fid, '  INV1: %s\n', inv1_file.name);
            fprintf(fid, '  INV2: %s\n', inv2_file.name);
            fprintf(fid, '  UNI:  %s\n', uni_file.name);
            fprintf(fid, 'Output: %s\n', output_filename);
            fprintf(fid, '\nProcessing parameters:\n');
            fprintf(fid, '  Beta: %.0f\n', beta);
            fprintf(fid, '  Volume dimensions: %dx%dx%d\n', size(V1,1), size(V1,2), size(V1,3));
            fprintf(fid, '\nResults:\n');
            fprintf(fid, '  Original std: %.2f\n', original_std);
            fprintf(fid, '  Denoised std: %.2f\n', denoised_std);
            fprintf(fid, '  Noise reduction: %.1f%%\n', noise_reduction);
            fprintf(fid, '  Correlation: %.4f\n', correlation_coeff);
            fprintf(fid, '  Processing time: %s\n', datestr(now));
            fclose(fid);
            
            fprintf('    Metrics: %.1f%% noise reduction, r=%.3f\n', noise_reduction, correlation_coeff);
            
        catch
            fprintf('    Warning: Could not save metrics\n');
        end
        
        fprintf('    Completed set %d\n', set_idx);
    end
    
    fprintf('  Completed %s\n', participant_id);
end

fprintf('\nAll participants processed!\n');
fprintf('Don''t forget to convert the denoised NIfTI files for FreeSurfer if needed.\n');