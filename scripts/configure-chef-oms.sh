
# Copy a file from a remote location to the local filesystem
#
# Arguments expected
# 1 - Remote URL for the OMSAgent configuration file

# Set a flag to restart the OMSAgent service
OMS_RESTART=0

# Download the file to the specified location
OMS_CHEF_CONF_FILE="/etc/opt/microsoft/omsagent/conf/omsagent.d/chef-server.conf"
if [ ! -f $OMS_CHEF_CONF_FILE ];
then
  wget $1 -O $OMS_CHEF_CONF_FILE

  # Ensure that the service is restarted
  OMS_RESTART=1
fi

# Create the directory for the position file for the logs
OMS_POS_DIR="/var/lib/omsagent"
if [ ! -d $OMS_POS_DIR ];
then
  mkdir -p $OMS_POS_DIR

  # Ensure the omsagent has ownership of this file
  chown omsagent $OMS_POS_DIR
fi

# Add the omsagent user to the opscode group so that it can read the chef
# server log files
usermod -G opscode -a omsagent

# If the configuration file has been downloaded then restart the service
if [ $OMS_RESTART -eq 1 ];
then
  service omsagent restart
fi