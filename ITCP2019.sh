#!/bin/bash
# variables
includedir=Validation/valid/includemasks
seed=injectbin.nii.gz

posterior=$includedir/injectbin-mask-y-7-include-posterior.nii.gz
anterior=$includedir/injectbin-mask-y-86-include-anterior.nii.gz
superior=$includedir/injectbin-mask-z-78-include-superior.nii.gz
inferior=$includedir/injectbin-mask-z-25-include-inferior.nii.gz
left=$includedir/injectbin-mask-x-72-include-left.nii.gz
right=$includedir/injectbin-mask-x-17-right-include.nii.gz

# tractography based steps
angles=$(echo {10..90..10})
thresholds=$(echo 0.1 0.2 0.5 1 2 3 4 5 6 {10..1000..20} {1000..5000..50} {5000..15000..500})
mkdir -p hcpl/thresholded/upload
mkdir -p hcpl/planarincludefilter

parallel tckgen {2}_odf_sfwm.mif {1}{2}_sfwm_{3}.tck -seed_image $seed -select 1M -minlength 20 -maxlength 50000 -trials 10000 -power 0.001 -algorithm iFOD2 -seed_unidirectional -force -angle {3} -nthreads 7 ::: hcpl/ :::+ finalhcpl ::: $angles

parallel tckedit -include {3} {1}{2}_sfwm_{5}.tck {1}planarincludefilter/{2}_{4}_{5}.tck -force ::: hcpl/ ::: finalhcpl ::: $posterior $anterior $superior $inferior $left $right :::+ posterior anterior superior inferior left right ::: $angles

parallel tckedit {1}{2}_posterior_{3}.tck {1}{2}_anterior_{3}.tck {1}{2}_superior_{3}.tck {1}{2}_inferior_{3}.tck {1}{2}_left_{3}.tck {1}{2}_right_{3}.tck {1}{2}_allsides_{3}.tck -force ::: hcpl/planarincludefilter/ :::+ finalhcpl ::: $angles

parallel tckmap -precise -template {1} {2}{3}_allsides_{4}.tck {2}{3}_allsides_{4}.nii.gz -force ::: $maskhcpl :::+ hcpl/planarincludefilter/ :::+ finalhcpl ::: $angles

thrdir=hcpl/planarincludefilter/thresholded
mkdir -p hcpl/planarincludefilter/thresholded/upload
parallel fslmaths {1}{2}_allsides_{3}.nii.gz -thr {4} {1}thresholded/{2}_allsides_{3}_{4}.nii.gz ::: hcpl/planarincludefilter/ :::+ finalhcpl ::: $angles ::: $thresholds

parallel 'AverageImages 3 {1}{2}_allsidesavg_{3}.nii.gz 1 {1}{2}_allsides_*_{3}.nii.gz' ::: $thrdir/ :::+ finalhcpl ::: $thresholds

parallel fslmaths {1}{2}_allsidesavg_{3}.nii.gz -thr 0.001 {1}upload/{2}_allsidesavg_{3}_thr.nii.gz ::: $thrdir/ :::+ finalhcpl ::: $thresholds

parallel zip -r {1}upload.zip {1}upload ::: $thrdir/