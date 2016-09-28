#!/bin/bash

#
# Script to handle the installation and configuration of various aspects of chef
#
# The script does not download any other scripts, it is up to the CustomScriptForLinux extension
# to do this.  The script assumes all the other scripts are in the same directory
#

# Declare an initialise variables
#
# Mode in which the script should run
MODE=""

# Chef Server Organisation
CHEF_ORGNAME=""

CHEF_ORG_DESCRIPTION=""

# Initial Chef User
CHEF_USER_NAME=""

# Fullname of the Chef User
CHEF_USER_FULLNAME=""

# Password for the Chef user
CHEF_USER_PASSWORD=""

# Email address for the new user
CHEF_USER_EMAILADDRESS=""

# Version of the various software
CHEF_SERVER_VERSION=""
COMPLIANCE_SERVER_VERSION=""
AUTOMATE_SERVER_VERSION=""

# Base URL to get the oms configuration files
OMS_BASE_URL=""

# FQDN of the Orchestration Server
ORCHESTRATION_SERVER=""

# License key for the automate server
AUTOMATE_LICENSE_KEY=""
AUTOMATE_LICENSE_KEY_PATH=""

CHEF_SERVER_URL=""

CHEF_OMS_CONFIG_FILE="omsagent-chef-server.conf"
AUTOMATE_OMS_CONFIG_FILE="omsagent-automate-server.conf"
AUTOMATE_LOGSTASH_CONFIG_FILE="logstash-chef-fluentd-output.conf"

#
# Do not change the variables below this
#
OIFS=$IFS
IFS=","
DRY_RUN=0
WEBUI=0
# --------------------------------------------

# FUNCTIONS ----------------------------------

function executeCmd()
{
  localcmd=$1

  if [ $DRY_RUN -eq 1 ]
  then
    echo $localcmd
  else
    eval $localcmd
  fi
}

function install()
{

  command_to_check=$1
  url=$2

  # Determine if the command exists or not
  COMMAND=`which $1`
  if [ "X$COMMAND" == "X" ]
  then

    # Determine if the downloaded file already exists or not
    download_file=`basename $url`
    if [ ! -f $download_file ]
    then
      echo -e "\tdownloading package"
      executeCmd "wget $url"
    fi

    # Install the package
    echo -e "\tinstalling package"
    executeCmd "dpkg -i $download_file"
  else
    echo -e "\talready installed"
  fi

}

function configOMS() 
{

  OMS_RESTART=0
  LOGSTASH_RESTART=0
  conf_file=$1
  url=$2
  type=$3
  
  # If the configuration file does not exist, download it
  if [ ! -f $conf_file ]
  then

    # Ensure that the parent directory exists
    parent_dir=`dirname $conf_file`
    if [ ! -d $parent_dir ]
    then
      executeCmd "mkdir -p $parent_dir"
    fi

    executeCmd "wget $url -O $conf_file"

    # Set the oms service to restart to pick up the new settings
    if [ "X$type" == "Xoms" ]
    then
      OMS_RESTART=1
    elif [ "X$type" == "Xlogstash" ]
    then
      LOGSTASH_RESTART=1
    fi
  fi

  # Ensure that the position directory exists
  OMS_POS_DIR="/var/lib/omsagent"
  if [ ! -d $OMS_POS_DIR ]
  then
    executeCmd "mkdir -p $OMS_POS_DIR"
    executeCmd "chown omsagent $OMS_POS_DIR"
  fi

  # Determine if the omsagent is a member of the opscode group
  # This is so that it can read the Chef Server file
  user=`id omsagent 2>/dev/null`
  if [ "X$user" != "X" ]
  then
    member=`id -nG omsagent | grep opscode`
    if [ "X$member" == "X" ]
    then
      executeCmd "usermod -G opscode -a omsagent"

      OMS_RESTART=1
    fi
  fi

  # Restart the OMS Agent service if flagged to do so
  if [ $OMS_RESTART -eq 1 ]
  then
    executeCmd "service omsagent restart"
  fi

  # Restart the Logstash server if flagged to do so
  if [ $LOGSTASH_RESTART -eq 1 ]
  then
    command=`which delivery-ctl`
    if [ "X$command" != "X" ]
    then
      executeCmd "delivery-ctl restart logstash"
    fi
  fi
}

# --------------------------------------------

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in

    -m|--mode)
      MODE="$2"
    ;;

    -o|--orgname)
      shift
      CHEF_ORGNAME=`echo $1 | tr '[:upper:]' '[:lower:]'`
    ;;

    -d|--org-description)
      shift
      CHEF_ORG_DESCRIPTION="$1"
    ;;

    -u|--username)
      shift
      CHEF_USER_NAME="$1"
    ;;

    -f|--fullname)
      shift
      CHEF_USER_FULLNAME="$1"
    ;;

    -p|--password)
      shift
      CHEF_USER_PASSWORD="$1"
    ;;

    -e|--email)
      shift
      CHEF_USER_EMAILADDRESS="$1"
    ;;

    -O|--orch-server)
      shift
      ORCHESTRATION_SERVER="$1"
    ;;

    -l|--license-key-path)
      shift
      AUTOMATE_LICENSE_KEY_PATH="$1"
    ;;

    -L|--license-key)
      shift
      AUTOMATE_LICENSE_KEY="$1"
    ;;

    -s|--chef-server-url)
      shift
      CHEF_SERVER_URL="$1"
    ;;

    --chef-version)
      shift
      CHEF_SERVER_VERSION="$1"
    ;;

    --compliance-version)
      shift
      COMPLIANCE_SERVER_VERSION="$1"
    ;;

    --automate-version)
      shift
      AUTOMATE_SERVER_VERSION="$1"
    ;;

    --oms-baseurl)
      shift
      OMS_BASE_URL="$1"
    ;;

    -D|--dryrun)
      DRY_RUN=1
    ;;

    -w|--webui)
      WEBUI=1
    ;;

  esac

  shift
done

# Select the operation to run based on the mode
for operation in $MODE
do
  
  # Run the necessary operations
  case $operation in

    chef-install)

      if [ "X$CHEF_SERVER_VERSION" != "X" ]
      then
        echo "Checking Chef Server"

        # Determine the download path for the chef server
        download_url=$(printf 'https://packages.chef.io/stable/ubuntu/14.04/chef-server-core_%s-1_amd64.deb' $CHEF_SERVER_VERSION)

        install chef-server-ctl $download_url
      fi 

    ;;

    compliance-install)

      if [ "X$COMPLIANCE_SERVER_VERSION" != "X" ]
      then
        echo "Checking Compliance Server"

        # Determine the download path for the chef server
        download_url=$(printf 'https://packages.chef.io/stable/ubuntu/16.04/chef-compliance_%s-1_amd64.deb' $COMPLIANCE_SERVER_VERSION)

        install compliance-server-ctl $download_url 
      fi
    ;;

    automate-install)

      if [ "X$AUTOMATE_SERVER_VERSION" != "X" ]
      then
        echo "Checking Automate Server"

        # Determine the download path for the chef server
        download_url=$(printf 'https://packages.chef.io/stable/ubuntu/16.04/delivery_%s-1_amd64.deb' $AUTOMATE_SERVER_VERSION)

        install delivery-ctl $download_url 
      fi

    ;;

    chef-oms)

      # Detect if the omsagent is installed before proceeding

      # Determine the url to the CHEF_OMS_FILE
      url=$(printf '%s/%s' $OMS_BASE_URL $CHEF_OMS_CONFIG_FILE)

      # Configure the OMS service on the Chef server
      configOMS "/etc/opt/microsoft/omsagent/conf/omsagent.d/chef-server.conf" $url oms

    ;;

    automate-oms)

      # Detect if the omsagent is installed before proceeding

      # Determine the url to the CHEF_OMS_FILE
      url=$(printf '%s/%s' $OMS_BASE_URL $AUTOMATE_OMS_CONFIG_FILE)

      # Configure the OMS service on the Chef server
      configOMS "/etc/opt/microsoft/omsagent/conf/omsagent.d/visibility.conf" $url oms

      # Automate requires additional configuration for logstash
      url=$(printf '%s/%s' $OMS_BASE_URL $AUTOMATE_LOGSTASH_CONFIG_FILE)
      configOMS "/opt/delivery/embedded/etc/logstash/conf.d/logstash-chef-fluent-output.conf" $url logstash
    ;;

    chef-configure)
      
      # Only proceeed if the variables are not null
      if [ "X$CHEF_USER_NAME" != "X" ] && \
         [ "X$CHEF_USER_FULLNAME" != "X" ] && \
         [ "X$CHEF_USER_EMAILADDRESS" != "X" ] && \
         [ "X$CHEF_USER_PASSWORD" != "X" ] && \
         [ "X$CHEF_ORGNAME" != "X" ] && \
         [ "X$CHEF_ORG_DESCRIPTION" != "X" ]
      then

        # Configure the chef server for the first time
        executeCmd "chef-server-ctl reconfigure"

        # Build up the command that needs to be run to create the new user
        cmd=$(printf 'chef-server-ctl user-create %s %s %s "%s" --filename %s.pem' $CHEF_USER_NAME $CHEF_USER_FULLNAME $CHEF_USER_EMAILADDRESS $CHEF_USER_PASSWORD $CHEF_USER_NAME)
        executeCmd $cmd

        # Create the organisation
        cmd=$(printf 'chef-server-ctl org-create %s "%s" --association_user %s --filename %s-validator.pem' $CHEF_ORGNAME $CHEF_ORG_DESCRIPTION $CHEF_USER_NAME $CHEF_ORGNAME)
        executeCmd $cmd

        # Create the delivery user
        cmd=$(printf 'chef-server-ctl user-create delivery Delivery User delivery@fakedomain.com "Password123!" --filename delivery.pem')
        executeCmd $cmd

        # Create the delivery organisation
        cmd=$(printf 'chef-server-ctl org-create delivery "Delivery Org" -a delivery --filename delivery-validator.pem')
        executeCmd $cmd

        # If an orchestration server has been specified then add the keys to it
        if [ "X$ORCHESTRATION_SERVER" != "X" ]
        then

          # As an orchestration server has been set then it must be part of an automate cluster
          # Create the data_token to be used and add to the orchestration server
          cmd=$(printf 'echo `openssl rand -base64 32` | sha256sum | cut -f 1 -d " " > data_token')
          executeCmd $cmd

          cmd=$(printf 'curl %s/v2/keys/automate/token -XPUT -d value="`cat data_token`"' $ORCHESTRATION_SERVER)
          executeCmd $cmd

          CHEF_SERVER_FILE="/etc/opscode/chef-server.rb"

          # Ensure that directory exists
          if [ ! -d `dirname $CHEF_SERVER_FILE` ]
          then
            mkdir -p `dirname $CHEF_SERVER_FILE`
          fi

          # Add this and the url for the automate server to the chef-server.rb file
          cmd=$(echo data_collector[\'root_url\'] = \"https://`hostname -f | sed 's/chef/automate/'`/data-collector/v0/\" >> $CHEF_SERVER_FILE)
          executeCmd $cmd

          cmd=$(echo data_collector[\'token\']=\"`cat data_token`\" >> $CHEF_SERVER_FILE)
          executeCmd $cmd

          cmd=$(printf 'curl %s/v2/keys/%s/validator -XPUT -d value="`cat %s-validator.pem | base64`"' $ORCHESTRATION_SERVER $CHEF_ORGNAME $CHEF_ORGNAME)
          executeCmd $cmd

          cmd=$(printf 'curl %s/v2/keys/delivery/user/delivery -XPUT -d value="`cat delivery.pem | base64`"' $ORCHESTRATION_SERVER)
          executeCmd $cmd
        fi

        # If the installation of the webui has been specified run the commands here
        if [ $WEBUI -eq 1 ]
        then
          executeCmd "chef-server-ctl install chef-manage"
          executeCmd "chef-manage-ctl reconfigure --accept-license"
        fi

        # Reconfigure the server for the last time
        executeCmd "chef-server-ctl reconfigure"
      fi

    ;;

    automate-configure)

      if [ "X$ORCHESTRATION_SERVER" != "X" ] && \
         [ "X$CHEF_SERVER_URL" != "X" ]
      then

        # Ensure that jq is installed so that it is possible to get the keys from the JSON from the orchestration server
        if [ ! -f /usr/bin/jq ]
        then
          executeCmd "apt-get install jq -y"
        fi

        # Build the command to get the validation key
        cmd=$(printf 'curl %s/v2/keys/delivery/user/delivery | jq -r .node.value | base64 -d > delivery.pem' $ORCHESTRATION_SERVER)
        executeCmd $cmd

        # If a license key has been specified as an option then write it out as file
        if [ "X$AUTOMATE_LICENSE_KEY" != "X" ]
        then
          echo $AUTOMATE_LICENSE_KEY | base64 -d > delivery.license
          AUTOMATE_LICENSE_KEY_PATH=delivery.license
        fi

        # Get the data_token from the orchestation server so it can be added to the configuration file
        cmd=$(printf 'curl %s/v2/keys/automate/token > data_token')
        executeCommand $cmd


        if [ ! -d /etc/delivery ]
        then
          mkdir /etc/delivery
        fi

        cmd=$(printf 'echo data_collector[\\"token\\"]=\\"`cat data_token`\\" >> /etc/delivery/delivery.rb')
        executeCmd $cmd

        # Run the command for the Automate server
        cmd=$(printf 'delivery-ctl setup -l %s -k $PWD/delivery.pem --server-url %s -f %s --configure -e Delivery --no-build-node > delivery-output.txt' $AUTOMATE_LICENSE_KEY_PATH $CHEF_SERVER_URL `hostname -f`)
        executeCmd $cmd

      fi



      # executeCmd "delivery-ctl reconfigure"
      
    ;;

  esac
done

# Restore system variables
IFS=$OIFS