#!/bin/bash -ex
# Hashicorp Consul Bootstraping 
# authors: tonynv@amazon.com, bchav@amazon.com
# date: oct,24,2016
# NOTE: This requires GNU getopt.  On Mac OS X and FreeBSD you much install GNU getopt



# Configuration 
PROGRAM='HashiCorp Consul Server'
CONSULVERSION='0.7.0'
CONSUL_TEMPLATE_VERSION='0.15.0'

##################################### Functions
function checkos () {
platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
else
   echo "[WARINING] This script is not supported on MacOS or freebsd"
   exit 1
fi
}

function usage () {
echo "$0 <usage>"
echo " "
echo "options:"
echo -e  "-h, --help \t show options for this script"
echo -e "--seedip \t Consul seed ip"
echo -e "--s3url \t specify the s3 URL  -S3url (https://s3.amazonaws.com/)"
echo -e "--s3bucket \t specify -s3bucket (your-bucket)"
echo -e "--s3prefix \t specify -s3prefix (prefix/to/key | folder/folder/file)"
}

function chkstatus () {
if [ $? -eq 0 ]
then
  echo "Script [PASS]"
else
  echo "Script [FAILED]" >&2
  exit 1
fi
}
##################################### Functions

# Call checkos to ensure platform is Linux
checkos

## set an initial value
S3BUCKET='NONE'
S3URL='NONE'
S3PREFIX='NONE'

# Read the options from cli input
TEMP=`getopt -o h:  --long help,seedip:,s3bucket:,s3url:,s3prefix: -n $0 -- "$@"`
eval set -- "$TEMP"


if [ $# == 1 ] ; then echo "No input provided! type ($0 --help) to see usage help" >&2 ; exit 1 ; fi

# extract options and their arguments into variables.
while true; do
  case "$1" in
    -h | --help)
  usage
  exit 1
  ;; 
    -m | --seedip ) 
  SEEDIP="$2"; 
  shift 
  ;;
    --s3url )
  S3URL="${2%/}"; 
  shift 2 
  ;;
    --s3bucket ) 
  S3BUCKET="$2"; 
  shift 2 
  ;;
    --s3prefix ) 
  S3PREFIX="${2%/}";
  shift 2 
  ;;
    -- ) 
  break;;
    *) break ;;
  esac
done


if [[ ${VERBOSE} == 'true' ]]; then
echo "consul = $CONSUL"
echo "s3bucket = $S3BUCKET"
echo "S3url = $S3URL"
echo "s3prefix = $S3PREFIX"
fi 

# Strip leading slash
if [[ $S3PREFIX == /* ]];then
      echo "Removing leading slash"
      #echo $S3PREFIX | sed -e 's/^\///'
      S3PREFIX=$(echo $S3PREFIX | sed -e 's/^\///')
fi

# Format S3 script path
S3SCRIPT_PATH="${S3URL}/${S3BUCKET}/${S3PREFIX}/scripts"
echo "S3SCRIPT_PATH = ${S3SCRIPT_PATH}"


# Uncomment to update on boot
#apt-get -y update

# SCRIPT VARIBLES
BINDIR='/usr/local/bin'
CONSULDIR='/opt/consul'
CONFIGDIR='${CONSULDIR}/config'
DATADIR='${CONSULDIR}/data'
CONSULCONFIGDIR='/etc/consul.d'
CONSULDOWNLOAD="https://releases.hashicorp.com/consul/${CONSULVERSION}/consul_${CONSULVERSION}_linux_amd64.zip"
CONSUL_TEMPLATE_DOWNLOAD="https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip"
CONSULWEBUI="https://releases.hashicorp.com/consul/${CONSULVERSION}/consul_${CONSULVERSION}_web_ui.zip"
INITCONF="${S3SCRIPT_PATH}/consul-init-server.conf"
INITFILE="/etc/init.d/consul-client"
CONSUL_UPSTART_CONF="${S3SCRIPT_PATH}/consul-server.conf"
CONSUL_UPSTART_FILE="/etc/init/consul.conf"

#CONSUL VARIABLES
echo  "Bootstrapping ${PROGRAM}"
EX_CODE=$?



## Install dependencies
apt-get -y install curl unzip jq
chkstatus

echo "Fetching Consul... from $CONSULDOWNLOAD"

curl -L $CONSULDOWNLOAD > /tmp/consul.zip
chkstatus

echo "Unpacking Consul to: ${BINDIR}"
unzip  /tmp/consul.zip -d  /usr/local/bin 
chmod 0755 /usr/local/bin/consul
chown root:root /usr/local/bin/consul
chkstatus

echo "Creating Consul Directories"
mkdir -p $CONSULCONFIGDIR
mkdir -p $CONSULDIR
mkdir -p $CONFIGDIR
mkdir -p $DATADIR
chmod 755 $CONSULDIR
chmod 755 $DATADIR
chmod 755 $CONFIGDIR
chmod 755 $CONSULCONFIGDIR
chkstatus

# Upstart config
echo "Confiure Init/Upstart Scripts (client)"
echo "Updating Seed IP ($SEED_IP)"
curl  $INITCONF  | sed -e s/__SEED_IP__/${SEEDIP}/ >  ${INITFILE}
curl  $CONSUL_UPSTART_CONF  | sed -e s/__SEED_IP__/${SEEDIP}/ > ${CONSUL_UPSTART_FILE}
chmod 755 ${INITFILE}
chmod 755 ${CONSUL_UPSTART_FILE}
chkstatus

update-rc.d consul-client defaults
update-rc.d consul-client enable
chkstatus

# Check Consul configuration
curl  ${S3SCRIPT_PATH}/client_json  >  ${CONSULCONFIGDIR}/base.json
chkstatus

echo "Install Consul Template"
curl -L $CONSUL_TEMPLATE_DOWNLOAD >  /tmp/consul_template.zip
unzip  /tmp/consul_template.zip -d  /usr/local/bin 
chmod 0755 /usr/local/bin/consul-template
chown root:root /usr/local/bin/consul-template
chkstatus


