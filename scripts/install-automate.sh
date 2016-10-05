
# Script to download, install and configure Chef Automate

# Command line parameters that are required in the script
# $1 - Automate License file
# $2 - Key for Chef Automate User
# $3 - Chef Server URL
# $4 - FQDN of the Automate Server
# $5 - Delivery Organisation Name

LOG_FILE="/root/automate-setup.log"

echo "$0 $1 $2 $3 $4 $5" > $LOG_FILE
echo >> $LOG_FILE

echo "Downloading Automate" >> $LOG_FILE

# Ensure that the package is not downloaded if it already exists
if [ ! -f delivery_0.5.125-1_amd64.deb ]
then
  wget https://packages.chef.io/stable/ubuntu/14.04/delivery_0.5.125-1_amd64.deb
fi

echo "Installing Automate" >> $LOG_FILE

# Only install if the `delivery-ctl` command does not exist
DELIVERY=`which delivery-ctl`
if [ "X$DELIVERY" == "X" ]
then
  dpkg -i delivery_0.5.125-1_amd64.deb
fi

which delivery-ctl >> $LOG_FILE

# Set a home variable for the script
export HOME="/root"

# Build up the command to be run
cmd="/usr/bin/delivery-ctl setup --license $1 --key $2 --server-url $3 --fqdn $4 -e "$5" --configure --no-build-node"

# Write out the command to a file so that it can be called using the `at` command
# echo $cmd > "/root/automate-setup.sh"

# Scedule the command to run in 1 minute
# at -f /root/automate-setup.sh now + 1min 

# echo "Setup command" >> $LOG_FILE
echo $cmd >> $LOG_FILE

# Execute the command
$cmd >> $LOG_FILE 2>> $LOG_FILE
