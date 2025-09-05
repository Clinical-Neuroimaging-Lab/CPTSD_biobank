SUBJECT_LIST=/Users/uqloestr/Desktop/scripts/C-PTSD/Subjectlist.txt

for subj in $(cat ${SUBJECT_LIST}) ; do

echo ${subj}

cd /Users/uqloestr/Desktop/DWI/${subj}

#############################################PRE-PROCESSING############################################################################

#denoise
#dwidenoise ${subj}_DWI.nii.gz ${subj}_DWI_denoised.nii.gz  -force

#extract AP b0s
#dwiextract  ${subj}_DWI_denoised.nii.gz -bzero ${subj}_B0_AP.nii.gz -fslgrad ${subj}_DWI.bvec ${subj}_DWI.bval

#average b0s
#mrmath ${subj}_B0_AP.nii.gz mean ${subj}_B0_AP_mean.nii.gz -axis 3

#mrcat ${subj}_B0_PA_1.nii.gz ${subj}_B0_PA_2.nii.gz ${subj}_B0_PA.nii.gz -axis 3

#mrmath ${subj}_B0_PA.nii.gz mean ${subj}_B0_PA_mean.nii.gz -axis 3

#combine AP and PA b0s into single 4D image series
#mrcat ${subj}_B0_AP_mean.nii.gz ${subj}_B0_PA_mean.nii.gz  ${subj}_B0_ALL.nii.gz -axis 3 -force

#brain mask
#bet2 ${subj}_B0_ALL.nii.gz  ${subj} -f 0.2  -m -n

#eddy & topup
#dwifslpreproc ${subj}_DWI_denoised.nii.gz ${subj}_DWI_denoised_preproc.nii.gz -rpe_pair -se_epi ${subj}_B0_ALL.nii.gz -pe_dir ap -fslgrad ${subj}_DWI.bvec ${subj}_DWI.bval -align_seepi -eddy_mask ${subj}_mask.nii.gz -eddy_options " --slm=linear" -force

#dwi bias correction
#dwibiascorrect ants ${subj}_DWI_denoised_preproc.nii.gz ${subj}_DWI_denoised_preproc_biasFieldCorr.nii.gz -fslgrad ${subj}_DWI.bvec ${subj}_DWI.bval -force

#####################################################T1 PROCESSING###################################################################

#T1 analyses in FreeSurfer
#recon-all -all -i ${subj}_T1.nii.gz -subjid ${subj} -sd /Users/uqloestr/Desktop/DWI/${subj}

#copy intensity normalized, skull-stripped T1 to subject folder, convert ot .nii and rename
#cp /Users/uqloestr/Desktop/DWI/UQPTSD002/${subj}/mri/norm.mgz /Users/uqloestr/Desktop/DWI/${subj}
#mrconvert norm.mgz ${subj}_T1_norm.nii.gz

#perform segmentation of WM, GM and CSF
#fast ${subj}_T1_norm.nii.gz

#rename the WM segmentation
#mv /Users/uqloestr/Desktop/DWI/${subj}/${subj}_T1_norm_pve_2.nii.gz /Users/uqloestr/Desktop/DWI/${subj}/${subj}_T1_WMseg.nii.gz

# First convert T2 to mgz format and get it into FreeSurfer space
#mri_convert ${subj}_T2w.nii.gz ${subj}_T2.mgz

# Register T2 to FreeSurfer's orig.mgz
#mri_robust_register --mov ${subj}_T2.mgz --dst ${subj}/mri/orig.mgz --lta ${subj}/T2toT1.lta --mapmov ${subj}/mri/T2.mgz --cost ROBENT --satit --iscale --entradius 2 --entcorrection
    
# Run hippocampal subfields and amygdala nuclei
#export SUBJECTS_DIR=/Users/uqloestr/Desktop/DWI/${subj}
#segmentHA_T2.sh ${subj} ${subj}/mri/T2.mgz T2 1 ${SUBJECTS_DIR}

# Run Thalamic nuclei
#segmentThalamicNuclei.sh ${subj} ${SUBJECTS_DIR} ${subj}/mri/T2.mgz T2 t2

###################################CO-Registrations T1/T2 to DWI#####################################################################

#co-registration of T1 to DWI space
#mrmath ${subj}_B0_ALL.nii.gz mean ${subj}_B0_ALL_mean.nii.gz  -axis 3

# Initial registration with brain mask
#flirt -in ${subj}_B0_ALL_mean.nii.gz -ref ${subj}_T1_norm.nii.gz -dof 6 -inweight ${subj}_mask.nii.gz -omat tmp.mat

# BBR registration using initial transform and brain mask
#flirt -in ${subj}_B0_ALL_mean.nii.gz -ref ${subj}_T1_norm.nii.gz -dof 6 -cost bbr -wmseg ${subj}_T1_WMseg.nii.gz -init tmp.mat -inweight ${subj}_mask.nii.gz -omat b02t1-bbr.mat -schedule ${FSLDIR}/etc/flirtsch/bbr.sch

# Convert transform for MRtrix
#transformconvert b02t1-bbr.mat ${subj}_B0_ALL_mean.nii.gz ${subj}_T1_norm.nii.gz flirt_import b02t1-bbr_mrtrix.txt -force

# Apply transform to get T1 in DWI space
#mrtransform -linear b02t1-bbr_mrtrix.txt -inverse ${subj}_T1_norm.nii.gz ${subj}_T1_coreg.nii.gz -force

#copy and convert T1 freesurfer segmentation image
#cp /Users/uqloestr/Desktop/DWI/UQPTSD002/UQPTSD002/mri/aparc+aseg.mgz /Users/uqloestr/Desktop/DWI/${subj}
#mrconvert aparc+aseg.mgz ${subj}_aparc+aseg.nii.gz

#get aparc+aseg into DWI space
#mrtransform -linear b02t1-bbr_mrtrix.txt -inverse ${subj}_aparc+aseg.nii.gz ${subj}_aparc+aseg_coreg.nii.gz -force -interp nearest

# Skull strip T2
#bet ${subj}_T2w.nii.gz ${subj}_T2_brain.nii.gz -R -f 0.5

#flirt -in ${subj}_mask.nii.gz -ref ${subj}_T1_coreg.nii.gz -applyxfm -init $FSLDIR/etc/flirtsch/ident.mat -out ${subj}_mask_resampled_T1.nii.gz -interp nearestneighbour

# Register T2 directly to the T1 that's already in DWI space
#flirt -in ${subj}_T2_brain.nii.gz -ref ${subj}_T1_coreg.nii.gz -dof 6 -refweight ${subj}_mask_resampled_T1.nii.gz -omat t2todwi.mat -out ${subj}_T2_coreg.nii.gz

########################################CONNECTOME#####################################################################################

# Run 5ttgen hsvs
#5ttgen hsvs ${subj} ${subj}_5TT.nii.gz -hippocampi aseg -thalami aseg -force
#mrtransform -linear b02t1-bbr_mrtrix.txt -inverse ${subj}_5TT.nii.gz ${subj}_5TT_coreg.nii.gz -force

# estimate the msmt response functions
#dwi2response msmt_5tt ${subj}_DWI_denoised_preproc_biasFieldCorr.nii.gz ${subj}_5TT.nii.gz out_wm out_gm out_csf -mask ${subj}_mask.nii.gz -fslgrad ${subj}_DWI.bvec ${subj}_DWI.bval -force

#convert pre-processed DWI image
#mrconvert ${subj}_DWI_denoised_preproc_biasFieldCorr.nii.gz -fslgrad ${subj}_DWI.bvec ${subj}_DWI.bval ${subj}_DWI_denoised_preproc_biasFieldCorr.mif

#perform global tractography
#tckglobal ${subj}_DWI_denoised_preproc_biasFieldCorr.mif out_wm -riso out_csf -riso out_gm -mask ${subj}_mask.nii.gz -niter 1e9 -fod ${subj}_FOD.nii.gz -fiso ${subj}_FISO.nii.gz ${subj}_global_tracks.tck

##########################################################TRACTSEG############################################################

#Run below commands in terminal directly
#Create a Python 3.7 Environment (x86 architecture):
#CONDA_SUBDIR=osx-64 conda create -n tractseg_env python=3.7

#Activate the Environment:
#conda init
#conda activate tractseg_env

# Install PyTorch (CPU-only)
#conda install pytorch torchvision torchaudio cpuonly -c pytorch
#pip install packaging

# Install TractSeg
#pip install TractSeg


#perform TractSeg
#TractSeg -i ${subj}_DWI_denoised_preproc_biasFieldCorr.nii.gz -o ${subj}_tractseg_output --raw_diffusion_input --csd_type csd --brain_mask ${subj}_mask.nii.gz --bvals ${subj}_DWI.bval --bvecs ${subj}_DWI.bvec

#tract segmentation
#TractSeg -i ${subj}_tractseg_output/peaks.nii.gz -o ${subj}_tractseg_output --output_type endings_segmentation

#tract orientation mapping (TOM)
#TractSeg -i ${subj}_tractseg_output/peaks.nii.gz -o ${subj}_tractseg_output --output_type TOM

#tracking on TOMs
#Tracking -i ${subj}_tractseg_output/peaks.nii.gz -o ${subj}_tractseg_output

#################################################################################################################################

#move FreeSurfer outputs out of DWI folder into separate folder
mv /Users/uqloestr/Desktop/DWI/${subj}/${subj} /Users/uqloestr/Desktop/FreeSurfer
mv /Users/uqloestr/Desktop/DWI/${subj}/fsaverage /Users/uqloestr/Desktop/FreeSurfer

done
