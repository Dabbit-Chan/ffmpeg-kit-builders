#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120

source "${SCRIPTDIR}/function-$host_platform.sh"
source "${SCRIPTDIR}/run-$host_platform.sh"

check_missing_packages # do this first since it's annoying to go through prompts then be rejected
intro                  # remember to always run the intro, since it adjust pwd
setup_build_environment


if [[ -n $run_only ]]; then
  echo -e "INFO: --- Executing single function: $run_only ---\n" | tee -a "$LOG_FILE"
  eval "$run_only" || exit_message 1 "unable to run $run_only"
  echo -e "INFO: --- Done executing single function: $run_only ---\n" | tee -a "$LOG_FILE"
elif [[ -n "$build_only" ]]; then
	if [[ $(is_integer "$build_only") != 0 ]]; then
    index=$(array_index_of "$build_only" "${BUILD_STEPS[@]}")
	else
		index=$build_only
	fi
	# Now, call the single requested build function by its index
	step_name="${BUILD_STEPS[$index]}"
	echo -e "INFO: --- Executing single build step: $step_name ---\n" | tee -a "$LOG_FILE"
	echo -e "WARNING: This may fail if previous dependencies havent been built yet." | tee -a "$LOG_FILE"
	#build_ffmpeg_dependency_only "$step_name"
	echo -e "INFO: --- Done building single build step: $step_name ---\n" | tee -a "$LOG_FILE"
elif [[ -n "$build_from" ]]; then
	if [[ $(is_integer "$build_from") != 0 ]]; then
    index=$(array_index_of "$build_from" "${BUILD_STEPS[@]}")
	else
		index=$build_from
	fi
	# Now, call the single requested build function by its index
	step_name="${BUILD_STEPS[$index]}"
	echo -e "INFO: --- Building dependencies from step: $step_name ---\n" | tee -a "$LOG_FILE"
	echo -e "WARNING: This may fail if previous dependencies havent been built yet." | tee -a "$LOG_FILE"
	#build_all_ffmpeg_dependencies "$step_name"
	echo -e "INFO: --- Done building dependencies from step: $step_name ---\n" | tee -a "$LOG_FILE"
else
	change_dir "$work_dir" || exit 1

	if trythy "$build_dependencies_only"; then
		echo -e "INFO: Building dependencies only..." | tee -a "$LOG_FILE"
		echo -e "WARNING: This may fail if previous dependencies havent been built yet." | tee -a "$LOG_FILE"
		#build_all_ffmpeg_dependencies
	elif truthy "$build_ffmpeg_only"; then
		echo -e "INFO: Building ffmpeg only..." | tee -a "$LOG_FILE"
		echo -e "WARNING: This may fail if previous dependencies havent been built yet." | tee -a "$LOG_FILE"
		#download_ffmpeg
		#install_ffmpeg
	elif truthy "$build_ffmpeg_kit_only"; then
		echo -e "INFO: Building ffmpeg-kit only..." | tee -a "$LOG_FILE"
		echo -e "WARNING: This may fail if previous dependencies havent been built yet." | tee -a "$LOG_FILE"
		#configure_ffmpeg_kit
		#install_ffmpeg_kit
		#create_linux_bundle
	else
		echo -e "INFO: Building all..." | tee -a "$LOG_FILE"
		#build_all_ffmpeg_dependencies 
		#download_ffmpeg               
		#install_ffmpeg                
		#configure_ffmpeg_kit          
		#install_ffmpeg_kit            
		#create_linux_bundle
	fi
fi
echo -e "$(date)" | tee -a "$LOG_FILE"
exit 0
