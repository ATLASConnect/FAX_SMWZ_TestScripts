#!/bin/sh

HelpFAX() { echo "source setup_fax.sh -X X509_USER_PROXY -R RUCIO_ACCOUNT -r root_version -x xrootd_version -h This help text" ; }

x509_proxy="/tmp/x509_Proxy"_${USER}
rucio_account=${USER}
root_version="current-SL6"
xrootd_version="current-SL6"

while [ "$#" -gt "0" ]
do
  case "$1" in
    -X)
       shift
       x509_proxy=$1
       ;;
    -R)
       shift
       rucio_account=$1
       ;;
    -r)
       shift
       root_version=$1
       ;;
    -x)
       shift
       xrootd_version=$1
       ;;
    -h)
       HelpFAX
       return 0
       ;;
    *)
       echo "Syntax Error"
       HelpFAX
       return 1
       ;;
  esac
  shift
done

echo ${root_version} ${xrootd_version} ${rucio_account} ${x509_proxy}
export X509_USER_PROXY=${x509_proxy}
export RUCIO_ACCOUNT=${rucio_account}
localSetupFAX --rootVersion=${root_version} --xrootdVersion=${xrootd_version}
localSetupPandaClient --noAthenaCheck
