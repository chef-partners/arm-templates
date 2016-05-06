#!/usr/bin/env bash

# Setup script to run the chef-server-ctl command to setup the
# chef server without having to log into it and setup manually
#
# Author: Russell Seymour
# Version: 0.1

# Define variables for use in the script
# Marketplace config file
MARKETPLACE_FILE="/etc/chef-marketplace/marketplace.rb"

# Analytics configuration file
ANALYTICS_FILE="/etc/opscode-analytics/opscode-analytics.rb"

# Marketplace command
MARKETPLACE_CMD="/usr/bin/chef-marketplace-ctl"

# Define the location for the log files
LOG_DIR="/var/log/chef-server-bootstrap"

# FUNCTIONS ---------------------------

show_help() {

  read -d '' help <<"BLOCK"
Usage: $0 [-h] -F

Configures the chef-server on an Azure Marketplace image

Arguments:
    -F (--fqdn)         - The external DNS name of the server

Options:
    -h (-? or --help)   - This help message

BLOCK

  echo "$help"
}

# -------------------------------------

# Create the switches for the script
while :; do

  # Get the key from the command line which will be evaluated
  key="$1"

  # set the variables based on the switches
  case $key in

    -h|-\?|--help)
      show_help
      exit
    ;;

    -F|--fqdn)
      if [ -n "$2" ]
      then
        FQDN="$2"
        shift
      else
        printf 'ERROR: "--fqdn" requires a value.\n' >&2
        exit 1
      fi
    ;;

    --)
      shift
      break
    ;;

    -?*)
      printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
      ;;

    *)
      break
  esac

  shift
done

# Check that the marketplace command exists
if [ ! -f $MARKETPLACE_CMD ]
then
  echo "Chef marketplace command cannot be found.  Was the Azure Marketplace image used to create this server?"
  exit 1
fi

# Ensure that the logdir exists
if [ ! -d $LOG_DIR ]
then
  echo "Creating log directory: $LOG_DIR"
  mkdir -p $LOG_DIR
fi

# Define the command log so that the commands used to set everything up can be seen
CMD_LOG="$LOG_DIR/cmd.log"
touch $CMD_LOG

# Update Ubuntu first
echo "Updating packages"
CMD='/usr/bin/apt-get update'
echo $CMD >> $CMD_LOG
$CMD >> $LOG_DIR/ubuntu.log 2>&1
CMD='/usr/bin/apt-get upgrade -y'
echo $CMD >> $CMD_LOG
$CMD >> $LOG_DIR/ubuntu.log 2>&1

# Set the FQDN in the marketplace configuration file
echo "Setting the FQDN"
echo "   API"
api_fqdn=$(printf 'api_fqdn "%s"' "${FQDN}")

# Determine that the marketplace file exists
if [ -f $MARKETPLACE_FILE ]
then
  echo $api_fqdn >> $MARKETPLACE_FILE
else
  echo "Marketplace file does not exist: ${MARKETPLACE_FILE}"
  exit 2
fi

echo "   Analytics"
analytics_fqdn=$(printf 'analytics_fqdn "%s"' "${FQDN}")

if [ -f $ANALYTICS_FILE ]
then
  echo $analytics_fqdn >> $ANALYTICS_FILE
else
  echo "Analytics file does not exist: ${ANALYTICS_FILE}"
  exit 2
fi

# Define the logfile
LOGFILE=$(printf "%s/setup.log" $LOG_DIR)

# Set the FQDN using the chef-marketplace-ctl command
CMD="${MARKETPLACE_CMD} hostname $FQDN"
echo $CMD >> $CMD_LOG
$CMD >> $LOG_DIR/setup.log 2>&1
