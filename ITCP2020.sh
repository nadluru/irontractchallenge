#!/bin/bash
# input
dwitype=(Output/hcpl_training Output/hcpl_validation)
seeds=(Training/prep.inject.nii.gz Validation/prep.inject.nii.gz)
dwi=(Training/prep.dwi.hcpl.nii.gz Validation/prep.dwi.hcpl.nii.gz)
bvals=(Training/ADDITIONAL/training/prep.bvalues.hcpl.txt Validation/ADDITIONAL/validation/prep.bvalues.hcpl.txt)
bvecs=(Training/ADDITIONAL/training/prep.gradients.hcpl.txt Validation/ADDITIONAL/validation/prep.gradients.hcpl.txt)
angles=({10..90..10})
suffix=1M

# csd
parallel -j4 -k --plus --bar '
dwi2response dhollander {1} {2}_out_sfwm.txt {2}_out_gm.txt {2}_out_csf.txt -fslgrad {3} {4} -force -nocleanup
dwi2mask {1} -fslgrad {3} {4} - | maskfilter - dilate {2}_{1/..}_dilatedMask.nii.gz -npass 3
dwi2fod msmt_csd {1} {2}_out_sfwm.txt {2}_odf_sfwm.mif {2}_out_gm.txt {2}_odf_gm.mif {2}_out_csf.txt {2}_odf_csf.mif -fslgrad {3} {4} -force -mask {2}_{1/..}_dilatedMask.nii.gz
' ::: ${dwi[@]} :::+ ${dwitype[@]} :::+ ${bvecs[@]} :::+ ${bvals[@]}

# tractography
parallel --dry-run -j2 tckgen {1}_odf_sfwm.mif {1}_sfwm_${suffix}_angle_{3}.tck -seed_image {2} -select $suffix -minlength 1 -maxlength 5000 -trials 10000 -power 0.001 -algorithm iFOD2 -seed_unidirectional -force -angle {3} -nthreads 7 ::: ${dwitype[@]} :::+ ${seeds[@]} ::: ${angles[@]}

# tckedit and tckmap
tckedit hcpl_training_sfwm_1M_angle_*.tck hcpl_training.tck
tckedit hcpl_validation_sfwm_1M_angle_*.tck hcpl_validation.tck

# epfl
parallel -j2 --dry-run tckmap -precise -template {1} {2}.tck {2}.nii.gz -force ::: ${seeds[@]} :::+ ${dwitype[@]}
parallel -j2 --dry-run 'mrcalc {}.nii.gz 1 -add -log10 - | mrfilter - smooth {}_log10_smooth.nii.gz -fwhm 0.5 -force' ::: ${dwitype[@]}

parallel mrstats {}_log10_smooth.nii.gz -output max -quiet ::: ${dwitype[@]} | tr -d ' ' | parallel 'seq 0 $(echo {2}/200|bc -l) {2} | parallel -I // --bar mrthreshold {1}_log10_smooth.nii.gz -abs // {1}_//_thr.nii.gz' ::: ${dwitype[@]} ::::+ -
# vumc
tckedit Output/hcpl_training.tck -include Training/trainingROIs.nii.gz Output/hcpl_training_vumc.tck
tckedit Output/hcpl_validation.tck -include Validation/validationROIs.nii.gz Output/hcpl_validation_vumc.tck

parallel -j2 --dry-run tckmap -precise -template {1} {2}_vumc.tck {2}_vumc.nii.gz -force ::: ${seeds[@]} :::+ ${dwitype[@]}
parallel -j2 --dry-run 'mrcalc {}_vumc.nii.gz 1 -add -log10 - | mrfilter - smooth {}_vumc_log10_smooth.nii.gz -fwhm 0.5 -force' ::: ${dwitype[@]}
parallel mrstats {}_vumc_log10_smooth.nii.gz -output max -quiet ::: ${dwitype[@]} | tr -d ' ' | parallel 'seq 0 $(echo {2}/200|bc -l) {2} | parallel -I // --bar mrthreshold {1}_vumc_log10_smooth.nii.gz -abs // {1}_vumc_//_thr.nii.gz' ::: ${dwitype[@]} ::::+ -
