#!/bin/sh
# $1 Input file type
# $2 1 local condor, local files, 2 local condor, FAX files, 3 condor flocking via Bosco, 4 ATLAS Connect
# $3 Start time of job submission script
# $4 ROOT version
# $5 XRootD version
# $6 X509_USER_PATH
# $7 RUCIO_ACCOUNT

# Setup to get run time of this script.
start=`date +%s`
let "elapsed = start - ${3}"
echo "Elapsed time waitng to start (s):" $elapsed
echo
echo "Input Arguments:" ${1} ${2} ${3} ${4} ${5} ${6} ${7}
echo

# Record Environment
echo "Environment"
env | sort
echo
if [[ -f .job.ad ]]; then
  echo ".job.ad"
  cat .job.ad
  echo
fi
if [[ -f .machine.ad ]]; then
  echo ".machine.ad"
  cat .machine.ad
  echo
fi
if [[ -f .job_wrapper_failure ]]; then
  echo ".job_wrapper_failure"
  echo
  cat .job_wrapper_failure
  echo
fi

# Setup Atlas Local Root Base from standard Location and
# use working directory as $HOME so it serves as ALRB scratch area
if [[ -z "${HOME}" ]]; then
  export HOME=${PWD}
  echo "Setting HOME to: " ${HOME}
  echo
fi
export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
# Setup Atlas Local Root Base
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh

# Get task Task (job within jobset)  and Job ID (jobset) numbers.
# NB: I take the convention that the tasks are numbered 1 to N and not 0 to N-1.
ProcId=`grep ProcId ${TMP}/.job.ad | cut -d' ' -f3`
let "task_id = ProcId + 1"
# Pad task id with leading zeros to use in file and directory names.
padded_task_id=`printf %04u ${task_id}`
ClusterId=`grep -v AutoClusterId ${TMP}/.job.ad | grep ClusterId | cut -d' ' -f3`
job_id=${ClusterId}

# Save location of working direct for Input/Output files.
# NB: For some workflows the directory tree where the program runs is not under work_dir.
work_dir=${PWD}

case "${2}" in
  1)# local condor, local files
    # Setup for Root
    if [[ ${4} != "current-SL6" ]]; then
      localSetupROOT ${4} --skipConfirm
    else
      localSetupROOT --skipConfirm
    fi
    mkdir ${padded_task_id}/
    cd ${padded_task_id}/
    ;;
  2)# local condor, FAX data access
    # Setup FAX (Sets up EMI, FAX, RUCIO, ROOT, XRootD)
    export X509_USER_PROXY=${PWD}/${6}
    export RUCIO_ACCOUNT=${7}
    localSetupFAX --rootVersion=${4} --xrootdVersion=${5} --skipConfirm
    # Confirm the grid proxy is available.
    voms-proxy-info --all
    mkdir ${padded_task_id}/
    cd ${padded_task_id}/
    ;;
  3)# condor flocking, FAX data access
    # Setup FAX (Sets up EMI, FAX, RUCIO, ROOT, XRootD)
    export X509_USER_PROXY=${PWD}/${6}
    export RUCIO_ACCOUNT=${7}
    localSetupFAX --rootVersion=${4} --xrootdVersion=${5} --skipConfirm
    # Confirm the grid proxy is available.
    voms-proxy-info --all
    ;;
  4)# ATLAS connect, FAX data access
    # Setup FAX (Sets up EMI, FAX, RUCIO, ROOT, XRootD)
    export X509_USER_PROXY=${PWD}/${6}
    export RUCIO_ACCOUNT=${7}
    localSetupFAX --rootVersion=${4} --xrootdVersion=${5} --skipConfirm
    # Confirm the grid proxy is available.
    voms-proxy-info --all
    ;;
  *)# Oopsie!
    echo "Reached unreachable case."
    return 7
    ;;
esac

# Locate input files for this task  within full list of input files.
let "first_line = ( ${task_id} - 1)  * 10 + 1"
let "last_line = first_line + 9"
input_file=input_${1}.txt
input_seq_file=input_${padded_task_id}.txt
output_seq_file=SMWZd3pdExample_${1}_${job_id}_${padded_task_id}.root

# Unpack example code directory tree.
tar xzf ${work_dir}/SMWZd3pdExample.lib.tgz

sed -n ${first_line},${last_line}p ${work_dir}/${input_file} > ${work_dir}/${input_seq_file}
bin/SMWZd3pdExample -f ${work_dir}/${input_seq_file} -o ${work_dir}/${output_seq_file}
rm -f ${work_dir}/${input_seq_file}

# Show final set of files.
echo
ls -al

# Clean up
case "${2}" in
  1)# local condor, local files
    cd ..
    rm -rf ${padded_task_id}/
    ;;
  2)# local condor, FAX data access
    cd ..
    rm -rf ${padded_task_id}/
    ;;
  3)# condor flocking, FAX data access
    ;;
  4)# ATLAS connect, FAX data access
    ;;
  *)# Oopsie!
    echo "Reached unreachable case."
    return 8
esac

# Print elapsed times for entire process and actual running of the example"
echo
end=`date +%s`
let "elapsed = end - start"
echo "Elapsed time since start of execution (s):" ${elapsed}
