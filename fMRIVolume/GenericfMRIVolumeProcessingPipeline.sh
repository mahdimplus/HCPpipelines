#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.2) 
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

########################################## PIPELINE OVERVIEW ########################################## 

# TODO

########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

if [ -z "${HCPPIPEDIR}" ]; then
	echo "GenericfMRIVolumeProcessingPipeline.sh: ABORTING - HCPPIPEDIR environment variable not set"
	exit 1
fi

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib         # Command line option functions
source ${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib  # Check processing mode requirements

################################################ SUPPORT FUNCTIONS ##################################################

# Validate necesary environment variables
validate_environment_vars()
{
	if [ -z "${FSLDIR}" ]; then
		log_Err_Abort "FSLDIR environment variable not set"
	fi

	log_Msg "Environment variables used - Start"
	log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
	log_Msg "FSLDIR: ${FSLDIR}"
	log_Msg "Environment variables used - End"
}

# check for incompatible FSL version
check_fsl_version()
{
	local fsl_version_file
	local fsl_version
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# get the current version of FSL in use
	fsl_version_file="${FSLDIR}/etc/fslversion"

	if [ -f ${fsl_version_file} ]; then
		fsl_version=$(cat ${fsl_version_file})
		log_Msg "Determined that the FSL version in use is ${fsl_version}"
	else
		log_Err_Abort "Cannot tell which version of FSL is in use"
	fi

	# break FSL version string into components: primary, secondary, and tertiary
	# FSL X.Y.Z would have X as primary, Y as secondary, and Z as tertiary versions

	fsl_version_array=(${fsl_version//./ })
	
	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}

	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}

	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# FSL version 6.0.0 is unsupported
	if [[ $(( ${fsl_primary_version} )) -eq 6 ]]; then
		if [[ $(( ${fsl_secondary_version} )) -eq 0 ]]; then
			if [[ $(( ${fsl_tertiary_version} )) -eq 0 ]]; then
				log_Err_Abort "FSL version 6.0.0 is unsupported. Please upgrade to at least version 6.0.1"
			fi
		fi
	fi
}

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

validate_environment_vars

check_fsl_version

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# parse arguments
Path=`opts_GetOpt1 "--path" $@`
log_Msg "Path: ${Path}"

Subject=`opts_GetOpt1 "--subject" $@`
log_Msg "Subject: ${Subject}"

NameOffMRI=`opts_GetOpt1 "--fmriname" $@`
log_Msg "NameOffMRI: ${NameOffMRI}"

fMRITimeSeries=`opts_GetOpt1 "--fmritcs" $@`
log_Msg "fMRITimeSeries: ${fMRITimeSeries}"

fMRIScout=`opts_GetOpt1 "--fmriscout" $@`
log_Msg "fMRIScout: ${fMRIScout}"

SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
log_Msg "SpinEchoPhaseEncodeNegative: ${SpinEchoPhaseEncodeNegative}"

SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
log_Msg "SpinEchoPhaseEncodePositive: ${SpinEchoPhaseEncodePositive}"

MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`  # Expects 4D volume with two 3D timepoints
log_Msg "MagnitudeInputName: ${MagnitudeInputName}"

PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`  
log_Msg "PhaseInputName: ${PhaseInputName}"

GEB0InputName=`opts_GetOpt1 "--fmapgeneralelectric" $@`
log_Msg "GEB0InputName: ${GEB0InputName}"

EchoSpacing=`opts_GetOpt1 "--echospacing" $@`  # *Effective* Echo Spacing of fMRI image, in seconds
log_Msg "EchoSpacing: ${EchoSpacing}"

deltaTE=`opts_GetOpt1 "--echodiff" $@`  
log_Msg "deltaTE: ${deltaTE}"

UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`  
log_Msg "UnwarpDir: ${UnwarpDir}"

FinalfMRIResolution=`opts_GetOpt1 "--fmrires" $@`  
log_Msg "FinalfMRIResolution: ${FinalfMRIResolution}"

# FIELDMAP, SiemensFieldMap, GeneralElectricFieldMap, or TOPUP
# Note: FIELDMAP and SiemensFieldMap are equivalent
DistortionCorrection=`opts_GetOpt1 "--dcmethod" $@`
log_Msg "DistortionCorrection: ${DistortionCorrection}"

BiasCorrection=`opts_GetOpt1 "--biascorrection" $@`
# Convert BiasCorrection value to all UPPERCASE (to allow the user the flexibility to use NONE, None, none, legacy, Legacy, etc.)
BiasCorrection="$(echo ${BiasCorrection} | tr '[:lower:]' '[:upper:]')"
log_Msg "BiasCorrection: ${BiasCorrection}"

GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`  
log_Msg "GradientDistortionCoeffs: ${GradientDistortionCoeffs}"

TopupConfig=`opts_GetOpt1 "--topupconfig" $@`  # NONE if Topup is not being used
log_Msg "TopupConfig: ${TopupConfig}"

dof=`opts_GetOpt1 "--dof" $@`
dof=`opts_DefaultOpt $dof 6`
log_Msg "dof: ${dof}"

RUN=`opts_GetOpt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)
log_Msg "RUN: ${RUN}"

#NOTE: the jacobian option only applies the jacobian of the distortion corrections to the fMRI data, and NOT from the nonlinear T1 to template registration
UseJacobian=`opts_GetOpt1 "--usejacobian" $@`
# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(echo ${UseJacobian} | tr '[:upper:]' '[:lower:]')"
log_Msg "UseJacobian: ${UseJacobian}"

MotionCorrectionType=`opts_GetOpt1 "--mctype" $@`  # use = "FLIRT" to run FLIRT-based mcflirt_acc.sh, or "MCFLIRT" to run MCFLIRT-based mcflirt.sh
MotionCorrectionType=`opts_DefaultOpt $MotionCorrectionType MCFLIRT` #use mcflirt by default

#error check
case "$MotionCorrectionType" in
    MCFLIRT|FLIRT)
        #nothing
    ;;
    
    *)
		log_Err_Abort "--mctype must be 'MCFLIRT' (default) or 'FLIRT'"
    ;;
esac

JacobianDefault="true"
if [[ $DistortionCorrection != "TOPUP" ]]
then
    #because the measured fieldmap can cause the warpfield to fold over, default to doing nothing about any jacobians
    JacobianDefault="false"
    #warn if the user specified it
    if [[ $UseJacobian == "true" ]]
    then
        log_Msg "WARNING: using --jacobian=true with --dcmethod other than TOPUP is not recommended, as the distortion warpfield is less stable than TOPUP"
    fi
fi
log_Msg "JacobianDefault: ${JacobianDefault}"

UseJacobian=`opts_DefaultOpt $UseJacobian $JacobianDefault`
log_Msg "After taking default value if necessary, UseJacobian: ${UseJacobian}"

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
	log_Err_Abort "the --usejacobian option must be 'true' or 'false'"
fi

# Setup PATHS
PipelineScripts=${HCPPIPEDIR_fMRIVol}
GlobalScripts=${HCPPIPEDIR_Global}

#Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
ScoutName="Scout"
OrigScoutName="${ScoutName}_orig"
OrigTCSName="${NameOffMRI}_orig"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${NameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${NameOffMRI}2standard"
Standard2OutputfMRITransform="standard2${NameOffMRI}"
QAImage="T1wMulEPI"
JacobianOut="Jacobian"
SubjectFolder="$Path"/"$Subject"
#note, this file doesn't exist yet, gets created by ComputeSpinEchoBiasField.sh during DistortionCorrectionAnd...
sebasedBiasFieldMNI="$SubjectFolder/$AtlasSpaceFolder/Results/$NameOffMRI/${NameOffMRI}_sebased_bias.nii.gz"

fMRIFolder="$Path"/"$Subject"/"$NameOffMRI"

# ------------------------------------------------------------------------------
#  Legacy Style Data Options
# ------------------------------------------------------------------------------


PreregisterTool=`opts_GetOpt1 "--preregistertool" $@`                    # what to use to preregister BOLDs before FSL BBR - epi_reg (default) or flirt
DoSliceTimeCorrection=`opts_GetOpt1 "--doslicetime" $@`                  # Whether to do slicetime correction (TRUE), FALSE to omit
SliceTimerCorrectionParameters=$(opts_GetOpt1 "--slicetimerparams" "$@") # A '@' separated list of FSL slicetimer options. Please see FSL slicetimer documentation for details.
                                                                         # Verbose (-v) is already turned on. TR is read from 'pixdim4' of the input NIFTI itself.
                                                                         # e.g. --slicetimerparams="--odd@--ocustom=<CustomInterleaveFile>"
BOLDMask=`opts_GetOpt1 "--boldmask" $@`                                  # Specifies what mask to use for the final bold:
                                                                         #   T1_fMRI_FOV: combined T1w brain mask and fMRI FOV masks (the default), 
                                                                         #   T1_DILATED_fMRI_FOV: a once dilated T1w brain based mask combined with fMRI FOV
                                                                         #   T1_DILATED2x_fMRI_FOV: a twice dilated T1w brain based mask combined with fMRI FOV, 
                                                                         #   fMRI_FOV: a fMRI FOV mask
                                                                         #   NOTE: When using SEBASED bias field correction, the mask will default to T1_fMRI_FOV
                                                                         #   as the bias field is masked already.
fMRIReference=`opts_GetOpt1 "--fmriref" $@`                              # Reference BOLD run name (i.e., --fmriname from run to be used as *reference*) to use as 
                                                                         #   motion correction target and to copy atlas (MNI152) registration from (or NONE; default).
                                                                         #   NOTE: The reference BOLD has to have been fully processed using fMRIVolume pipeline, so
                                                                         #   that a distortion correction and atlas (MNI152) registration solution for the reference
                                                                         #   BOLD already exists. Also, the reference BOLD must have been acquired using the same
                                                                         #   phase encoding direction, or it can not serve as a valid reference. 
fMRIReferenceReg=`opts_GetOpt1 "--fmrirefreg" $@`                        # In the cases when BOLD image is registered to a specified BOLD reference, this option 
                                                                         #   specifies whether to use 'linear' or 'nonlinear' registration to reference BOLD.
                                                                         #   Default is 'linear'.



# Defaults
PreregisterTool=`opts_DefaultOpt $PreregisterTool "epi_reg"`
DoSliceTimeCorrection=`opts_DefaultOpt $DoSliceTimeCorrection "FALSE"`   # WARNING: This LegacyStyleData option of slice timing correction is performed before motion correction 
                                                                         #   (as is typically done in legacy-style brain imaging) and thus assumes that the brain is motionless. 
                                                                         #   Errors in temporal interpolation will occur in the presence of head motion and may also disrupt 
                                                                         #   data quality measures as shown in Power et al 2017 PLOS One "Temporal interpolation alters motion in fMRI
                                                                         #   scans: Magnitudes and consequences for artifact detection." Slice timing correction and motion correction 
                                                                         #   would ideally be performed simultaneously; however, this is not currently supported by any major software 
                                                                         #   tool. HCP-Style fast TR fMRI data acquisitions (TR<=1s) avoid the need for slice timing correction, 
                                                                         #   provide major advantages for fMRI denoising, and are recommended. 
                                                                         #   No slice timing correction is done by default.  

# If --dcmethod=NONE                                                     # WARNING: The fMRIVolume pipeline is being run without appropriate distortion correction of the fMRI image. 
                                                                         #   This is NOT RECOMMENDED under normal circumstances. We will attempt 6 DOF FreeSurfer BBR registration of 
                                                                         #   the distorted fMRI to the undistorted T1w image. Distorted portions of the fMRI data will not align with 
                                                                         #   the cortical ribbon. In HCP data 30% of the cortical surface will be misaligned by at least half cortical 
                                                                         #   thickness and 10% of the cortical surface will be completely misaligned by a full cortical thickness. 
                                                                         #   At a future time, we may be able to add support for fieldmap-less distortion correction. At this time, 
                                                                         #   however, despite ongoing efforts, this problem is unsolved and no extant approach has been successfully 
                                                                         #   shown to demonstrate clear improvement according to the accuracy standards of HCP-Style data analysis when 
                                                                         #   compared to gold-standard fieldmap-based correction.

# Defaults

fMRIReference=`opts_DefaultOpt $fMRIReference "NONE"`
BOLDMask=`opts_DefaultOpt $BOLDMask "T1_fMRI_FOV"`

# ------------------------------------------------------------------------------
#  Compliance check
# ------------------------------------------------------------------------------

ProcessingMode=`opts_GetOpt1 "--processing-mode" $@`
ProcessingMode=`opts_DefaultOpt $ProcessingMode "HCPStyleData"`
Compliance="HCPStyleData"
ComplianceMsg=""
ComplianceWarn=""

# -- No distortion correction method

if [ "${DistortionCorrection}" = 'NONE' ]; then
  ComplianceMsg+=" --dcmethod=NONE"
  Compliance="LegacyStyleData"
  log_Warn "The fMRIVolume pipeline is being run without appropriate distortion correction"
  log_Warn "  of the fMRI image. This is NOT RECOMMENDED under normal circumstances. We will "
  log_Warn "  attempt 6 DOF FreeSurfer BBR registration of the distorted fMRI to the undistorted"
  log_Warn "  T1w image. Distorted portions of the fMRI data will not align with the cortical ribbon."
  log_Warn "  In HCP data 30% of the cortical surface will be misaligned by at least half cortical "
  log_Warn "  thickness and 10% of the cortical surface will be completely misaligned by a full "
  log_Warn "  cortical thickness. At a future time, we may be able to add support for fieldmap-less "
  log_Warn "  distortion correction. At this time, however, despite ongoing efforts, this problem is"
  log_Warn "  unsolved and no extant approach has been successfully shown to demonstrate clear "
  log_Warn "  improvement according to the accuracy standards of HCP-Style data analysis when compared"
  log_Warn "  to gold-standard fieldmap-based correction."
fi

# -- Slice timing correction

if [ "${DoSliceTimeCorrection}" = 'TRUE' ]; then
  ComplianceMsg+=" --doslicetime=TRUE --slicetimerparams=${SliceTimerCorrectionParameters}"
  Compliance="LegacyStyleData"
  log_Warn "This LegacyStyleData option of slice timing correction is performed before motion"
  log_Warn "  correction (as is typically done in legacy-style brain imaging) and thus assumes that the"
  log_Warn "  brain is motionless. Errors in temporal interpolation will occur in the presence of head"
  log_Warn "  motion and may also disrupt data quality measures as shown in Power et al 2017 PLOS One "
  log_Warn "  'Temporal interpolation alters motion in fMRI scans: Magnitudes and consequences for"
  log_Warn "  artifact detection.' Slice timing correction and motion correction would ideally be performed"
  log_Warn "  simultaneously; however, this is not currently supported by any major software tool. HCP-Style"
  log_Warn "  fast TR fMRI data acquisitions (TR<=1s) avoid the need for slice timing correction, provide"
  log_Warn "  major advantages for fMRI denoising, and are recommended."
fi


# -- Use of nonstandard BOLD mask

if [ "${BOLDMask}" != 'T1_fMRI_FOV' ]; then
  if [ "${BOLDMask}" != "T1_DILATED_fMRI_FOV" ] && [ "${BOLDMask}" != "T1_DILATED2x_fMRI_FOV" ] && [ "${BOLDMask}" != "fMRI_FOV" ] ; then
    log_Err_Abort "--boldmask=${BOLDMask} is invalid! Valid options are: T1_fMRI_FOV (default), T1_DILATED_fMRI_FOV, T1_DILATED2x_fMRI_FOV, fMRI_FOV."
  fi
  ComplianceMsg+=" --boldmask=${BOLDMask}"
  Compliance="LegacyStyleData"
fi

# -- Use of external BOLD reference

if [ "$fMRIReference" = "NONE" ]; then
  fMRIReferenceReg="NONE"    
  fMRIReferencePath="NONE"
  ReferenceResultsFolder="NONE"
else
  fMRIReferenceReg=`opts_DefaultOpt $fMRIReferenceReg "linear"`

  # set reference and check if external reference (if one is specified) exists 

  fMRIReferencePath="$Path"/"$Subject"/"$fMRIReference"
  log_Msg "Using reference image from ${fMRIReferencePath}"
  fMRIReferenceImage="$fMRIReferencePath"/"$ScoutName"_gdc
  fMRIReferenceImageMask="$fMRIReferencePath"/"$ScoutName"_gdc_mask
  ReferenceResultsFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"/"$ResultsFolder"/"$fMRIReference"

  if [ "$fMRIReferencePath" = "$fMRIFolder" ] ; then
    log_Err_Abort "Specified BOLD reference (--fmriref=${fMRIReference}) is the same as the current BOLD (--fmriname=${NameOffMRI})!"
  fi

  if [ `${FSLDIR}/bin/imtest ${fMRIReferenceImage}` -eq 0 ] ; then
    log_Err_Abort "Intended BOLD Reference does not exist (${fMRIReferenceImage})!"
  fi 

  if [ `${FSLDIR}/bin/imtest ${fMRIReferenceImageMask}` -eq 0 ] ; then
    log_Err_Abort "Intended BOLD Reference mask does not exist (${fMRIReferenceImageMask})!"
  fi 

  if [ ! -d "$ReferenceResultsFolder" ] ; then
    log_Err_Abort "Reference results folder does not exist and can not be used (${ReferenceResultsFolder})!"
  fi 

  # print warning

  log_Warn "You are using an external reference (--fmriref=${fMRIReference}) for motion registration and"
  log_Warn "  distortion correction and registration to T1w image. Pleaase consider using this option only"
  log_Warn "  in cases when only one BOLD Reference image is available or when processing low resolution"
  log_Warn "  legacy BOLD images. Please make sure that the reference BOLD (--fmriref=${fMRIReference})"
  log_Warn "  and the current bold (--fmriname=${NameOffMRI}) were acquired using the same acquisition"
  log_Warn "  parameters, e.g. phase encoding direction."
fi

# -- Use of nonlinear registration to external BOLD reference

if [ "${fMRIReferenceReg}" = "nonlinear" ] ; then
  ComplianceMsg+=" --fmrirefreg=${fMRIReferenceReg}"
  Compliance="LegacyStyleData"
fi

check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"

# -- End compliance check

#error check bias correction opt
case "$BiasCorrection" in
    NONE)
        UseBiasFieldMNI=""
		;;
    LEGACY)
        UseBiasFieldMNI="${fMRIFolder}/${BiasFieldMNI}.${FinalfMRIResolution}"
		;;    
    SEBASED)
        if [[ "$DistortionCorrection" != "TOPUP" ]]
        then
            log_Err_Abort "SEBASED bias correction is only available with --dcmethod=TOPUP"
        fi
        UseBiasFieldMNI="$sebasedBiasFieldMNI"
		;;
    "")
        log_Err_Abort "--biascorrection option not specified"
		;;
    *)
        log_Err_Abort "unrecognized value for bias correction: $BiasCorrection"
		;;
esac

########################################## DO WORK ########################################## 

T1wFolder="$Path"/"$Subject"/"$T1wFolder"
AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"

mkdir -p ${T1wFolder}/Results/${NameOffMRI}

if [ ! -e "$fMRIFolder" ] ; then
  log_Msg "mkdir ${fMRIFolder}"
  mkdir "$fMRIFolder"
fi
${FSLDIR}/bin/imcp "$fMRITimeSeries" "$fMRIFolder"/"$OrigTCSName"

# --- Do slice time correction if indicated
if [ $DoSliceTimeCorrection = "TRUE" ] ; then
    log_Msg "Running slice timing correction using FSL's 'slicetimer' tool"
    TR=`${FSLDIR}/bin/fslval "$fMRIFolder"/"$OrigTCSName" pixdim4`
    log_Msg "TR: ${TR}"

    IFS='@' read -a SliceTimerCorrectionParametersArray <<< "$SliceTimerCorrectionParameters"
    ${FSLDIR}/bin/immv "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigTCSName"_prestc
    ${FSLDIR}/bin/slicetimer -i "$fMRIFolder"/"$OrigTCSName"_prestc -o "$fMRIFolder"/"$OrigTCSName" -r ${TR} -v "${SliceTimerCorrectionParametersArray[@]}"
    ${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigTCSName"_prestc
fi

#Create fake "Scout" if it doesn't exist
if [ $fMRIScout = "NONE" ] ; then
  ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigScoutName" 0 1
else
  ${FSLDIR}/bin/imcp "$fMRIScout" "$fMRIFolder"/"$OrigScoutName"
fi

if [ $DistortionCorrection = "NONE" ] ; then
    # Processing is more robust to registration problems if the fMRI is in the same orientation as the
    # standard template (MNI152) images, which can be accomplished using FSL's `fslreorient2std`.
    # HOWEVER, if you reorient, other parameters (such as UnwarpDir) need to be adjusted accordingly.
    # Rather than deal with those complications here, we limit reorienting to DistortionCorrection=NONE condition.

    # First though, detect if reorienting is even necessary
    xorient=`$FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_xorient | tr -d ' '`
    yorient=`$FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_yorient | tr -d ' '`
    zorient=`$FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_zorient | tr -d ' '`

    log_Msg "$fMRIFolder/$OrigTCSName: xorient=${xorient}, yorient=${yorient}, zorient=${zorient}"

    if [[ "$xorient" != "Right-to-Left" && "$xorient" != "Left-to-Right" || \
          "$yorient" != "Posterior-to-Anterior" || \
          "$zorient" != "Inferior-to-Superior" ]] ; then
      reorient=TRUE
    else 
      reorient=FALSE
    fi

    if [ $reorient = "TRUE" ] ; then
      log_Warn "Performing fslreorient2std! Please take that into account when using volume BOLD images in further analyses!"

      # --- reorient BOLD
      ${FSLDIR}/bin/immv "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigTCSName"_pre2std
      ${FSLDIR}/bin/fslreorient2std "$fMRIFolder"/"$OrigTCSName"_pre2std "$fMRIFolder"/"$OrigTCSName"
      ${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigTCSName"_pre2std

      # --- reorient SCOUT
      ${FSLDIR}/bin/immv "$fMRIFolder"/"$OrigScoutName" "$fMRIFolder"/"$OrigScoutName"_pre2std
      ${FSLDIR}/bin/fslreorient2std "$fMRIFolder"/"$OrigScoutName"_pre2std "$fMRIFolder"/"$OrigScoutName"
      ${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigScoutName"_pre2std
    fi
fi


#Gradient Distortion Correction of fMRI
log_Msg "Gradient Distortion Correction of fMRI"
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
    log_Msg "mkdir -p ${fMRIFolder}/GradientDistortionUnwarp"
    mkdir -p "$fMRIFolder"/GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
		   --workingdir="$fMRIFolder"/GradientDistortionUnwarp \
		   --coeffs="$GradientDistortionCoeffs" \
		   --in="$fMRIFolder"/"$OrigTCSName" \
		   --out="$fMRIFolder"/"$NameOffMRI"_gdc \
		   --owarp="$fMRIFolder"/"$NameOffMRI"_gdc_warp
	
    log_Msg "mkdir -p ${fMRIFolder}/${ScoutName}_GradientDistortionUnwarp"	
    mkdir -p "$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
		   --workingdir="$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp \
		   --coeffs="$GradientDistortionCoeffs" \
		   --in="$fMRIFolder"/"$OrigScoutName" \
		   --out="$fMRIFolder"/"$ScoutName"_gdc \
		   --owarp="$fMRIFolder"/"$ScoutName"_gdc_warp
	
	if [[ $UseJacobian == "true" ]]
	then
	    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc -mul "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian "$fMRIFolder"/"$NameOffMRI"_gdc
	    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$ScoutName"_gdc -mul "$fMRIFolder"/"$ScoutName"_gdc_warp_jacobian "$fMRIFolder"/"$ScoutName"_gdc
	fi
else
    log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$NameOffMRI"_gdc
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc "$fMRIFolder"/"$NameOffMRI"_gdc_warp 0 3
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp -mul 0 "$fMRIFolder"/"$NameOffMRI"_gdc_warp
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigScoutName" "$fMRIFolder"/"$ScoutName"_gdc
    #make fake jacobians of all 1s, for completeness
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$OrigScoutName" -mul 0 -add 1 "$fMRIFolder"/"$ScoutName"_gdc_warp_jacobian
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc_warp "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian 0 1
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian -mul 0 -add 1 "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian
fi

log_Msg "mkdir -p ${fMRIFolder}/MotionCorrection"
mkdir -p "$fMRIFolder"/MotionCorrection

${RUN} "$PipelineScripts"/MotionCorrection.sh \
       "$fMRIFolder"/MotionCorrection \
       "$fMRIFolder"/"$NameOffMRI"_gdc \
       "$fMRIFolder"/"$ScoutName"_gdc \
       "$fMRIFolder"/"$NameOffMRI"_mc \
       "$fMRIFolder"/"$MovementRegressor" \
       "$fMRIFolder"/"$MotionMatrixFolder" \
       "$MotionMatrixPrefix" \
       "$MotionCorrectionType"

# EPI Distortion Correction and EPI to T1w Registration
DCFolderName=DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
DCFolder=${fMRIFolder}/${DCFolderName}

if [ $fMRIReference = "NONE" ] ; then
  log_Msg "EPI Distortion Correction and EPI to T1w Registration"

  if [ -e ${DCFolder} ] ; then
      ${RUN} rm -r ${DCFolder}
  fi
  log_Msg "mkdir -p ${DCFolder}"
  mkdir -p ${DCFolder}

  ${RUN} ${PipelineScripts}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh \
         --workingdir=${DCFolder} \
         --scoutin=${fMRIFolder}/${ScoutName}_gdc \
         --t1=${T1wFolder}/${T1wImage} \
         --t1restore=${T1wFolder}/${T1wRestoreImage} \
         --t1brain=${T1wFolder}/${T1wRestoreImageBrain} \
         --fmapmag=${MagnitudeInputName} \
         --fmapphase=${PhaseInputName} \
         --fmapgeneralelectric=${GEB0InputName} \
         --echodiff=${deltaTE} \
         --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
         --SEPhasePos=${SpinEchoPhaseEncodePositive} \
         --echospacing=${EchoSpacing} \
         --unwarpdir=${UnwarpDir} \
         --owarp=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
         --biasfield=${T1wFolder}/${BiasField} \
         --oregim=${fMRIFolder}/${RegOutput} \
         --freesurferfolder=${T1wFolder} \
         --freesurfersubjectid=${Subject} \
         --gdcoeffs=${GradientDistortionCoeffs} \
         --qaimage=${fMRIFolder}/${QAImage} \
         --method=${DistortionCorrection} \
         --topupconfig=${TopupConfig} \
         --ojacobian=${fMRIFolder}/${JacobianOut} \
         --dof=${dof} \
         --fmriname=${NameOffMRI} \
         --subjectfolder=${SubjectFolder} \
         --biascorrection=${BiasCorrection} \
         --usejacobian=${UseJacobian} \
         --preregistertool=${PreregisterTool}

else
    log_Msg "linking EPI distortion correction and T1 registration from ${fMRIReference}"
    if [ -d ${DCFolder} ] ; then
        log_Warn "     ... removing preexisiting files"
        rm -r ${DCFolder}
    fi
    if [ -h ${DCFolder} ] ; then
        log_Warn "     ... removing stale link"
        rm ${DCFolder}
    fi
    ln -s ${fMRIReferencePath}/${DCFolderName} ${DCFolder}
 
    if [ `${FSLDIR}/bin/imtest ${T1wFolder}/xfms/${fMRIReference}2str` -eq 0 ]; then
      log_Err_Abort "The expected ${T1wFolder}/xfms/${fMRIReference}2str from the reference (${fMRIReference}) does not exist!"    
    else
      ${FSLDIR}/bin/imcp ${T1wFolder}/xfms/${fMRIReference}2str ${T1wFolder}/xfms/${fMRI2strOutputTransform}
    fi
fi

#One Step Resampling
log_Msg "One Step Resampling"
log_Msg "mkdir -p ${fMRIFolder}/OneStepResampling"

mkdir -p ${fMRIFolder}/OneStepResampling
${RUN} ${PipelineScripts}/OneStepResampling.sh \
       --workingdir=${fMRIFolder}/OneStepResampling \
       --infmri=${fMRIFolder}/${OrigTCSName}.nii.gz \
       --t1=${AtlasSpaceFolder}/${T1wAtlasName} \
       --fmriresout=${FinalfMRIResolution} \
       --fmrifolder=${fMRIFolder} \
       --fmri2structin=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
       --struct2std=${AtlasSpaceFolder}/xfms/${AtlasTransform} \
       --owarp=${AtlasSpaceFolder}/xfms/${OutputfMRI2StandardTransform} \
       --oiwarp=${AtlasSpaceFolder}/xfms/${Standard2OutputfMRITransform} \
       --motionmatdir=${fMRIFolder}/${MotionMatrixFolder} \
       --motionmatprefix=${MotionMatrixPrefix} \
       --ofmri=${fMRIFolder}/${NameOffMRI}_nonlin \
       --freesurferbrainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask} \
       --biasfield=${AtlasSpaceFolder}/${BiasFieldMNI} \
       --gdfield=${fMRIFolder}/${NameOffMRI}_gdc_warp \
       --scoutin=${fMRIFolder}/${OrigScoutName} \
       --scoutgdcin=${fMRIFolder}/${ScoutName}_gdc \
       --oscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin \
       --ojacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution} \
       --fmrirefpath=${fMRIReferencePath} \
       --fmrirefreg=${fMRIReferenceReg}

log_Msg "mkdir -p ${ResultsFolder}"
mkdir -p ${ResultsFolder}

#now that we have the final MNI fMRI space, resample the T1w-space sebased bias field related outputs
#the alternative is to add a bunch of optional arguments to OneStepResampling that just do the same thing
#we need to do this before intensity normalization, as it uses the bias field output
if [[ ${DistortionCorrection} == "TOPUP" ]]
then
    if [ "$fMRIReference" = "NONE" ]; then        
        #create MNI space corrected fieldmap images
        ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${DCFolder}/PhaseOne_gdc_dc_unbias -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -o ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${DCFolder}/PhaseTwo_gdc_dc_unbias -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -o ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc
        ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc    
    else        
        #as these have been already computed, we can copy them from the reference bold
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseOne_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseOne_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseTwo_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseTwo_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc
    fi

    #create MNINonLinear final fMRI resolution bias field outputs
    if [[ ${BiasCorrection} == "SEBASED" ]]
    then
        if [ "$fMRIReference" = "NONE" ]; then  
            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/sebased_bias_dil.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz
            
            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/sebased_reference_dil.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz       

            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/${NameOffMRI}_dropouts.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_dropouts.nii.gz

            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_raw.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz
            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_field.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz
        else
            #as these have been already computed, we can copy them from the reference bold
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_sebased_bias.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_sebased_reference.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_dropouts.nii.gz ${ResultsFolder}/${NameOffMRI}_dropouts.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_pseudo_transmit_raw.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_pseudo_transmit_field.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz
        fi
    fi
fi

#Intensity Normalization and Bias Removal
log_Msg "Intensity Normalization and Bias Removal"
${RUN} ${PipelineScripts}/IntensityNormalization.sh \
       --infmri=${fMRIFolder}/${NameOffMRI}_nonlin \
       --biasfield=${UseBiasFieldMNI} \
       --jacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution} \
       --brainmask=${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution} \
       --ofmri=${fMRIFolder}/${NameOffMRI}_nonlin_norm \
       --inscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin \
       --oscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm \
       --usejacobian=${UseJacobian} \
       --boldmask=${BOLDMask}

#Copy selected files to ResultsFolder
${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}.nii.gz
${RUN} cp ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef.nii.gz
${RUN} cp ${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_${JacobianOut}.nii.gz
${RUN} cp ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}
${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_mask.nii.gz ${ResultsFolder}/${NameOffMRI}_fovmask.nii.gz
${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_finalmask.nii.gz ${ResultsFolder}/${NameOffMRI}_finalmask.nii.gz

${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_finalmask.stats.txt ${ResultsFolder}/${NameOffMRI}_finalmask.stats.txt
${RUN} cp ${fMRIFolder}/${MovementRegressor}.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/${MovementRegressor}_dt.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_RelativeRMS.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_AbsoluteRMS.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_RelativeRMS_mean.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_AbsoluteRMS_mean.txt ${ResultsFolder}

#Basic Cleanup
${FSLDIR}/bin/imrm ${fMRIFolder}/${NameOffMRI}_nonlin_norm

#Econ
#${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigTCSName"
#${FSLDIR}/bin/imrm "$fMRIFolder"/"$NameOffMRI"_gdc
#${FSLDIR}/bin/imrm "$fMRIFolder"/"$NameOffMRI"_mc

log_Msg "Completed"

