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
CHEF_PUSHJOBS_VERSION="2.1.0"
CHEFDK_VERSION=""

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

# Chef Gate Details
CHEF_GATE_DEB_URL="https://s3-us-west-2.amazonaws.com/bjcpublic/chef-gate-latest.deb"
CHEF_GATE_DEB_CHECKSUM="778bd4aab9ac5a0d79c97f814ffa10551aa71971fa14936cbfbb43cf4c51fc88"

# List of the FQDN for the build nodes
BUILD_NODE_PREFIX=""
BUILD_NODE_COUNT=0

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
    echo $localcmd
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

    --chefdk-version)
      shift
      CHEFDK_VERSION="$1"
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

    --build-node-prefix)
      shift
      BUILD_NODE_PREFIX="$1"
    ;;

    --build-node-count)
      shift
      BUILD_NODE_COUNT=$1
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

        # Ensure that the main user specified in the template has access to the delivery organisation as well
        cmd=$(printf 'chef-server-ctl org-user-add delivery %s -a' $CHEF_USER_NAME)
        executeCmd $cmd

        # If an orchestration server has been specified then add the keys to it
        if [ "X$ORCHESTRATION_SERVER" != "X" ]
        then

          # As an orchestration server has been set then it must be part of an automate cluster
          # Create the data_token to be used and add to the orchestration server
          cmd=$(openssl rand -base64 32 | sha256sum | cut -f 1 -d " " > data_token)
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

          # Configure the Chef part of the Compliance integration
          gate_filename=`basename $CHEF_GATE_DEB_URL`
          cmd=$(printf 'wget %s -O %s' $CHEF_GATE_DEB_URL $gate_filename)
          executeCmd $cmd

          # Check that the checkum of the downloaded file and the one specified match
          download_checksum=`sha256sum $gate_filename | cut -f 1 -d " "`
          if [ "$download_checksum" == "$CHEF_GATE_DEB_CHECKSUM" ]
          then

            # Everything matches so configure the Chef server
            cmd=$(printf 'dpkg -i %s' $gate_filename)
            executeCmd $cmd

            # Add more information to the CHEF_SERVER_FILE regarding the location of the compliance server
            read -r -d '' CONTENT <<-'EOH'
oc_id['applications'] ||= {}
oc_id['applications']['compliance-server'] = {
  'redirect_uri' => 'https://%s/auth/Chef%%20Server/callback'
}
oc_id['administrators'] = ['admin']
EOH

            # Ensure the hostname of the compliance server is set correctly
            printf -v CONTENT "$CONTENT" `hostname -f | sed s/chef/compliance/`

            # Append the content to the file
            cmd=$(echo "$CONTENT" >> $CHEF_SERVER_FILE)
            executeCmd $cmd

            # Create the upstream Nginx definition
            read -r -d '' NGINX_UPSTREAM <<-'EOH'
#
# Chef Compliance upstream definition
#
upstream compliance {
  server %s:443;
}
EOH

            printf -v NGINX_UPSTREAM "$NGINX_UPSTREAM" `hostname -f | sed s/chef/compliance/`

            cmd=$(echo "$NGINX_UPSTREAM" > /var/opt/opscode/nginx/etc/addon.d/50_compliance_upstreams.conf)
            executeCmd $cmd

            # Restart the nginx service
            executeCmd "chef-server-ctl restart nginx"

            # Reconfigure the chef server so that the clientId and Secret are generated for the application
            executeCmd "chef-server-ctl reconfigure"

            # Get the necessary tokens
            RES=/etc/opscode/oc-id-applications/compliance-server.json
            clientid="$(cat "$RES" | grep uid | grep "\w*" -o | tail -n1)"
            clientsecret="$(cat "$RES" | grep secret | grep "\w*" -o | tail -n1)"

            # Add the id and secret to the orchestration server for use on the compliance machine
            cmd=$(printf 'curl %s/v2/keys/compliance/oc-id/uid -XPUT -d value="%s"' $ORCHESTRATION_SERVER $clientid)
            executeCmd $cmd

            cmd=$(printf 'curl %s/v2/keys/compliance/oc-id/secret -XPUT -d value="%s"' $ORCHESTRATION_SERVER $clientsecret)
            executeCmd $cmd

            # create the necessary environment variables for the chef gate
            cmd=$(printf 'https://%s' `hostname -f` > /opt/opscode/sv/chef_gate/env/CHEF_GATE_CHEF_SERVER_URL)
            executeCmd $cmd

            cmd=$(printf 'https://%s' `hostname -f | sed s/chef/compliance/` > /opt/opscode/sv/chef_gate/env/CHEF_GATE_OIDC_ISSUER_URL)
            executeCmd $cmd

            # Need to set the secret for the CHEF_GATE_COMPLIANCE_SECRET
            # Generate a secret for the COMPLIANCE and add to the orchestration server
            cmd=$(openssl rand -base64 32 | sha256sum | cut -f 1 -d " " > /opt/opscode/sv/chef_gate/env/CHEF_GATE_COMPLIANCE_SECRET)
            executeCmd $cmd

            # Add to the orchestration server
            cmd=$(printf 'curl %s/v2/keys/compliance/chef-gate/secret -XPUT -d value="`cat /opt/opscode/sv/chef_gate/env/CHEF_GATE_COMPLIANCE_SECRET`"' $ORCHESTRATION_SERVER)
            executeCmd $cmd

            # Stop the chef_gate service until the CHEF_GATE_OIDC_CLIENT_ID is set
            cmd=$(/opt/opscode/embedded/bin/sv stop chef_gate)

            # Create a new user and an SSH key for the user so that the compliance server can SSH and set the OIDC_CLIENT_ID
            # User
            cmd=$(useradd -d /home/compliance -m compliance)
            executeCmd $cmd

            cmd=$(usermod -G sudo -a compliance)
            executeCmd $cmd

            # Ensure that the compliance user is able to get to root without a password
            cmd="echo compliance ALL=\(ALL\) NOPASSWD:ALL > /etc/sudoers.d/91-automate-cluster-setup"
            executeCmd $cmd

            # SSH key
            cmd=$(mkdir -p /home/compliance/.ssh && ssh-keygen -b 4096 -N '' -f /home/compliance/.ssh/id_rsa)
            executeCmd $cmd

            cmd=$(cat /home/compliance/.ssh/id_rsa.pub > /home/compliance/.ssh/authorized_keys)
            executeCmd $cmd

            cmd=$(chown -R compliance:compliance /home/compliance)
            executeCmd $cmd

            cmd=$(chmod 600 /home/compliance/.ssh/authorized_keys)
            executeCmd $cmd

            # Add the RSA key to the orchestration server
            cmd=$(printf 'curl %s/v2/keys/compliance/sshkey -XPUT -d value="`cat /home/compliance/.ssh/id_rsa | base64`"' $ORCHESTRATION_SERVER)
            executeCmd $cmd

            # Download the push jobs package so that it can be added to the installation
            download_url=$(printf 'https://packages.chef.io/stable/ubuntu/16.04/opscode-push-jobs-server_%s-1_amd64.deb' $CHEF_PUSHJOBS_VERSION)
            executeCmd "wget $download_url"

            # Install the chef jobs application
            cmd=$(printf 'chef-server-ctl install opscode-push-jobs-server --path $PWD/%s' `basename $download_url`)
            executeCmd $cmd

            executeCmd "chef-server-ctl reconfigure"
            executeCmd "opscode-push-jobs-server-ctl reconfigure"

          fi
          

        fi

        # If the installation of the webui has been specified run the commands here
        if [ $WEBUI -eq 1 ]
        then
          executeCmd "chef-server-ctl install chef-manage"
          executeCmd "chef-manage-ctl reconfigure --accept-license"

          # Reconfigure the server for the last time
          executeCmd "chef-server-ctl reconfigure"
        fi

        
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
          AUTOMATE_LICENSE_KEY_PATH="${PWD}/delivery.license"
        fi

        # Get the data_token from the orchestation server so it can be added to the configuration file
        cmd=$(printf 'curl %s/v2/keys/automate/token | jq -r .node.value > data_token' $ORCHESTRATION_SERVER)
        executeCmd $cmd

        if [ ! -d /etc/delivery ]
        then
          mkdir /etc/delivery
        fi

        cmd=$(printf 'echo data_collector[\\"token\\"]=\\"`cat data_token`\\" >> /etc/delivery/delivery.rb')
        executeCmd $cmd

        # A home directory needs to be set for the delivery command to complete succesfully
        export HOME="/root"

        # Run the command for the Automate server
        cmd=$(printf 'delivery-ctl setup -l %s -k $PWD/delivery.pem --server-url %s -f %s --configure -e Delivery --no-build-node > delivery-output.txt' $AUTOMATE_LICENSE_KEY_PATH $CHEF_SERVER_URL `hostname -f`)
        executeCmd $cmd

        # Create the user that has been specified
        cmd=$(printf 'delivery-ctl create-user Delivery %s --password %s --roles admin' $CHEF_USER_NAME $CHEF_USER_PASSWORD)
        executeCmd $cmd
      fi



      # executeCmd "delivery-ctl reconfigure"
      
    ;;

    compliance-configure)

      # Reconfigure chef-compliance and accept the license key
      cmd="chef-compliance-ctl reconfigure --accept-license"
      executeCmd $cmd

      # Create the user and set the password for the software
      cmd=$(printf 'chef-compliance-ctl user-create %s %s' $CHEF_USER_NAME $CHEF_USER_PASSWORD)
      executeCmd $cmd

      # Restart compliance for the new user
      executeCmd "chef-compliance-ctl restart"

      if [ "X$ORCHESTRATION_SERVER" != "X" ]
      then

        # Ensure that jq is installed so that it is possible to get the keys from the JSON from the orchestration server
        if [ ! -f /usr/bin/jq ]
        then
          executeCmd "apt-get install jq -y"
        fi

        chef_hostname=`hostname -f | sed 's/compliance/chef/'`

        # get the oc-id details from the orchestration server
        cmd=$(printf 'curl %s/v2/keys/compliance/oc-id/uid | jq -r .node.value' $ORCHESTRATION_SERVER)
        clientID=`eval $cmd`
        cmd=$(printf 'curl %s/v2/keys/compliance/oc-id/secret | jq -r .node.value' $ORCHESTRATION_SERVER)
        clientSecret=`eval $cmd`

        # Create command that will add the authentication to the compliance server
        cmd=$(printf 'chef-compliance-ctl auth add --type ocid --id "Chef Server" --insecure true --client-id "%s" --client-secret "%s" --chef-url "https://%s"' $clientID $clientSecret $chef_hostname)
        executeCmd $cmd

        # Get the secret and add to the server
        cmd=$(printf 'curl %s/v2/keys/compliance/chef-gate/secret | jq -r .node.value > /opt/chef-compliance/sv/core/env/CHEF_GATE_COMPLIANCE_SECRET' $ORCHESTRATION_SERVER)
        executeCmd $cmd

        cmd="chef-compliance-ctl reconfigure"
        executeCmd $cmd

        # Download the SSHkey from the orchestration server so that the server can copy the OIDC_CLIENT_ID to the right file
        cmd=$(mkdir ~/.ssh)
        executeCmd $cmd

        cmd=$(printf 'curl %s/v2/keys/compliance/sshkey | jq -r .node.value | base64 -d > /root/.ssh/chef_server_key' $ORCHESTRATION_SERVER)
        executeCmd $cmd

        # Set the permissions for the key
        cmd="chmod 0600 /root/.ssh/chef_server_key"
        executeCmd $cmd

        # Copy the OIDC_CLIENT_ID to the chef server
        cmd=$(printf 'scp -oStrictHostKeyChecking=no -i /root/.ssh/chef_server_key /opt/chef-compliance/sv/core/env/OIDC_CLIENT_ID compliance@%s:CHEF_GATE_OIDC_CLIENT_ID' $chef_hostname)
        executeCmd $cmd

        # Move the OIDC_CLIENT_ID to the correct location and restart chef_gate
        cmd=$(printf 'ssh -oStrictHostKeyChecking=no -i /root/.ssh/chef_server_key -t -t compliance@%s sudo mv CHEF_GATE_OIDC_CLIENT_ID /opt/opscode/sv/chef_gate/env' $chef_hostname)
        executeCmd $cmd

        cmd=$(printf 'ssh -oStrictHostKeyChecking=no -i /root/.ssh/chef_server_key -t -t compliance@%s sudo chmod 0644 /opt/opscode/sv/chef_gate/env/CHEF_GATE_OIDC_CLIENT_ID' $chef_hostname)
        executeCmd $cmd

        cmd=$(printf 'ssh -oStrictHostKeyChecking=no -i /root/.ssh/chef_server_key -t -t compliance@%s sudo /opt/opscode/embedded/bin/sv restart chef_gate' $chef_hostname)
        executeCmd $cmd

      fi
    ;;

    build-node)

      # Ensure that jq is installed so that it is possible to get the keys from the JSON from the orchestration server
      if [ ! -f /usr/bin/jq ]
      then
        executeCmd "apt-get install jq -y"
      fi

      # Create the new user for the build node
      cmd=$(useradd -d /home/build -m build)
      executeCmd $cmd

      cmd=$(usermod -G sudo -a build)
      executeCmd $cmd

      # Ensure that the compliance user is able to get to root without a password
      cmd="echo build ALL=\(ALL\) NOPASSWD:ALL > /etc/sudoers.d/91-automate-build-user"
      executeCmd $cmd

      # SSH key
      cmd=$(mkdir -p /home/build/.ssh)
      executeCmd $cmd

      # Get the key from the orchestration server
      cmd=$(printf 'curl %s/v2/keys/buildnode/sshpubkey | jq -r .node.value | base64 -d >> /home/build/.ssh/authorized_keys' $ORCHESTRATION_SERVER)
      executeCmd $cmd

      cmd=$(chown -R build:build /home/build)
      executeCmd $cmd

      cmd=$(chmod 600 /home/build/.ssh/authorized_keys)
      executeCmd $cmd      

    ;;

    automate-build-nodes)

      # Ensure that jq is installed so that it is possible to get the keys from the JSON from the orchestration server
      if [ ! -f /usr/bin/jq ]
      then
        executeCmd "apt-get install jq -y"
      fi

      # Download ChefDK for the bootstrap
      download_url=$(printf 'https://packages.chef.io/stable/ubuntu/12.04/chefdk_%s-1_amd64.deb' $CHEFDK_VERSION)
      executeCmd "wget $download_url"

      # Get the private key to use to communicate with the build node
      cmd=$(printf 'curl %s/v2/keys/buildnode/sshprivkey | jq -r .node.value | base64 -d > $PWD/buildnode' $ORCHESTRATION_SERVER)
      executeCmd $cmd

      # Configure automate to communicate with the build nodes
      count=1
      while [ $count -le $BUILD_NODE_COUNT ]
      do

        # Determine the name of the node to contact to perform the bootstrap
        # Azure has internal DNS for the machines so using the name will work here and is derived from the count
        # and the prefix that has been supplied
        node=$(printf '%s-%s' $BUILD_NODE_PREFIX $count)

        # build up the command to run to set up the build server
        cmd=$(printf 'delivery-ctl install-build-node --fqdn %s --username build --password none --installer $PWD/%s --ssh-identity-file $PWD/buildnode --port 22 --overwrite-registration' $node `basename $download_url`)
        executeCmd $cmd

        # increment the loop counter
        (( count++ ))
      done
    ;;

    orchestration)

      # Create ssh keys that will be used for the build nodes
      executeCmd "ssh-keygen -b 4096 -N '' -f /root/buildnode"

      # Add the keys to the orchestration server
      cmd=$(printf 'curl http://127.0.0.1:4001/v2/keys/buildnode/sshpubkey -XPUT -d value="`cat /root/buildnode.pub | base64`"')
      executeCmd $cmd

      cmd=$(printf 'curl http://127.0.0.1:4001/v2/keys/buildnode/sshprivkey -XPUT -d value="`cat /root/buildnode | base64`"')
      executeCmd $cmd

    ;;

  esac
done

# Restore system variables
IFS=$OIFS