#!/bin/sh
# submit_jobset.sh Submits FAX, condor flocking, and ATLAS connect stress testing jobs.
# -w Working Directory (default .)
# -n Number of Jobs (default 1)
# -i Input File Type (default smwz_p1328_p1329_rcc_FAX))
# -j Job Type:  1 local batch using condor, local files, 2 local batch using condor, FAX files, 3 condor flocking using Bosco,
#               4 ATLAS Connect, 5 local background jobs, local files, 6 local background jobs, FAX files (default 3)
# -r ROOT version (default current-SL6)
# -x XRootD Version needed for FAX data access (default current-SL6)
# -X X509_USER_PROXY needed for FAX data access and condor flocking (defualt /tmp/x509up_u<uid>)
# -R RUCIO_ACCOUNT needed for FAX data accecc (default $USER)
function HelpSubmitJobset() { echo "source submit_jobset.sh -w working_directory -n number_of_jobs -i input_file_type -j job_type -r root_version -x xrootd_version -X X509_USER_PROXY -R RUCIO_ACCOUNT -h Print this help message" ; }

start=`date +%s`

working_directory=.
number_of_jobs=1
input_file_type=smwz_p1328_p1329_rcc_FAX
job_type=3
root_version="current-SL6"
xrootd_verstion="current_sl6"

while [ "$#" -gt "0" ]; do
  case ${1} in
    -w)
      shift
      working_directory=${1}
      ;;
    -n)
      shift
      number_of_jobs=${1}
      ;;
    -i)
      shift
      input_file_type=${1}
      ;;
    -j)
      shift
      job_type=${1}
      ;;
    -r)
      shift
      root_version=${1}
      ;;
    -x)
      shift
      xrootd_version=${1}
      ;;
    -X)
       shift
       export X509_USER_PROXY=${1}
       ;;
    -R)
      shift
      export RUCIO_ACCOUNT=${1}
      ;;
    -h)
       HelpSubmitJobset
       return 0
       ;;
    *)
       echo "Syntax Error"
       HelpSubmitJobset
       return 1
       ;;
  esac
  shift
done

echo ${working_directory} ${number_of_jobs} ${input_file_type} ${job_type} ${root_version} ${xrootd_version} ${X509_USER_PROXY} ${RUCIO_ACCOUNT}

if [[ ${job_type} -lt 1 || ${job_type} -gt 6 ]]; then
  echo "Job type code out of range - should be 1-6"
  return 5
fi

if [[ ${job_type} -eq 2 || ${job_type} -eq 3 ||  ${job_type} -eq 4 || ${job_type} -eq 6 ]]; then

  if [[ -e ${X509_USER_PROXY} ]]; then
    proxycreatetime=`date -r ${X509_USER_PROXY} +%s`
    let "elapsed = start - proxycreatetime"
    if [[ ${elapsed} -gt 172800 ]]; then
      echo "Proxy too old - renew proxy."
      return 1
    fi
  else
    echo "Proxy not found."
    return 2
  fi
fi

if [[ -e ${working_directory} ]]; then
  echo "Working directory exists and will not be overwritten."
  return 3
fi

input_data_file_list=input_${input_file_type}.txt
if [[ ! -e ${input_data_file_list} ]]; then
  echo "Text file containing list of input data files missing."
  return 4
fi

if [[ ${job_type} -ge 1 && ${job_type} -le 4 ]]; then # condor submission
  export Number_of_Jobs=${number_of_jobs}
  export Input_File_Type=${input_file_type}
  export Job_Type=${job_type}
  export ROOT_Version=${root_version}
  export XRootD_Version=${xrootd_version}
  export Start=${start}
else # put jobs in background
  export ClusterId=${start}
fi

mkdir ${working_directory}/
cp ${input_data_file_list} ${working_directory}/
cp SMWZd3pdExample_run.sh ${working_directory}/ 
cp SMWZd3pdExample.lib.tgz ${working_directory}/ 
cd ${working_directory}/

case "${job_type}" in
  1) # local condor, local files
    cp ../SMWZd3pdExample_local.jdl .
    condor_submit -disable SMWZd3pdExample_local.jdl
    ;;
  2) # local condor, FAX files
    cp ${X509_USER_PROXY} ./x509_Proxy
    cp ../SMWZd3pdExample_local_FAX.jdl .
    condor_submit -disable SMWZd3pdExample_local_FAX.jdl
    ;;
  3) # condor flocking, FAX files
    cp ${X509_USER_PROXY} ./x509_Proxy
    cp ../SMWZd3pdExample_bosco.jdl .
    condor_submit -disable SMWZd3pdExample_bosco.jdl
    ;;
  4) # ATLAS Connect, FAX files
    cp ${X509_USER_PROXY} ./x509_Proxy
    cp ../SMWZd3pdExample_connect.jdl .
    condor_submit -disable SMWZd3pdExample_connect.jdl
    ;;
  5) # background jobs, local files
    i=0
    while [ ${i} -lt ${number_of_jobs} ]; do
      export ProcId=${i}
      let "TaskId = i + 1"
      source SMWZd3pdExample_run.sh ${input_file_type} ${job_type} ${start} ${root_version} dummy0 dummy1 dummy2 >& SMWZd3pdExample_${input_file_type}_${ClusterId}_"`printf %04u ${TaskId}`".log &
      let "i = i + 1"
    done
    ;;
  6) # background jobs, FAX files
    cp ${X509_USER_PROXY} ./x509_Proxy
    i=0
    while [ ${i} -lt ${number_of_jobs} ]; do
      export ProcId=${i}
      let "TaskId = i + 1"
      source SMWZd3pdExample_run.sh ${input_file_type} ${job_type} ${start} ${root_version} ${xrootd_version} x509_Proxy ${RUCIO_ACCOUNT} >& SMWZd3pdExample_${input_file_type}_${ClusterId}_"`printf %04u ${TaskId}`".log &
      let "i = i + 1"
    done
    ;;
  *) # oopsie
    echo "Reached unreachable case."
    return 6
    ;;
esac

cd ..
