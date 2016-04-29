#!/usr/bin/env bash

# Setup script to run the chef-server-ctl command to setup the
# chef server without having to log into it and setup manually
#
# Author: Russell Seymour
# Version: 0.1

# Define variables for use in the script
# Marketplace config file
MARKETPLACE_FILE="/etc/chef-marketplace/marketplace.rb"

# Marketplace command
MARKETPLACE_CMD="/usr/bin/chef-marketplace-ctl"

# Define the location for the log files
LOG_DIR="/var/log/chef-server-bootstrap"

# FUNCTIONS ---------------------------

show_help() {
  #echo "Usage: $0 [-h] -F -u -p -f -l -e -o"
  #echo ""
  #echo "Configures the chef-server on an Azure Marketplace image"
  #echo ""
  #echo "Arguments:"
  #echo "    -F (--fqdn)    - The external DNS name of the server"

  read -d '' help <<"BLOCK"
Usage: $0 [-h] -F -u -p -f -l -e -o

Configures the chef-server on an Azure Marketplace image

Arguments:
    -F (--fqdn)         - The external DNS name of the server
    -u (--username)     - Admin username for the chef server
    -p (--password)     - Password for the admin username
    -f (--firstname)    - First name of the admin account
    -l (--lastname)     - Last name of the admin account
    -e (--emailaddress) - Email address for the account
    -o (--org)          - Organisation for the chef server

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

    -u|--username)
      if [ -n "$2" ]
      then
        USERNAME="$2"
        shift
      else
        printf 'ERROR: "--username" requires a value.\n' >&2
        exit 1
      fi
    ;;

    -p|--password)
      if [ -n "$2" ]
      then
        PASSWORD="$2"
        shift
      else
        printf 'ERROR: "--password" requires a value.\n' >&2
        exit 1
      fi
    ;;

    -f|--firstname)
      if [ -n "$2" ]
      then
        FIRSTNAME="$2"
        shift
      else
        printf 'ERROR: "--firstname" requires a value.\n' >&2
        exit 1
      fi
    ;;

    -l|--lastname)
      if [ -n "$2" ]
      then
        LASTNAME="$2"
        shift
      else
        printf 'ERROR: "--lastname" requires a value.\n' >&2
        exit 1
      fi
    ;;

    -e|--emailaddress)
      if [ -n "$2" ]
      then
        EMAILADDRESS="$2"
        shift
      else
        printf 'ERROR: "--emailaddress" requires a value.\n' >&2
        exit 1
      fi
    ;;

    -o|--organisation|--org|--organization)
      if [ -n "$2" ]
      then
        ORG="$2"
        shift
      else
        printf 'ERROR: "--org" requires a value.\n' >&2
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
api_fqdn=$(printf 'api_fqdn "%s"' "${FQDN}")

# Determine that the marketplace file exists
if [ -f $MARKETPLACE_FILE ]
then
  echo $api_fqdn >> $MARKETPLACE_FILE
else
  echo "Marketplace file does not exist: ${MARKETPLACE_FILE}"
  exit 2
fi

# Define the logfile
LOGFILE=$(printf "%s/setup.log" $LOG_DIR)

# Set the FQDN using the chef-marketplace-ctl command
CMD="${MARKETPLACE_CMD} hostname $FQDN > $LOGFILE"
echo $CMD >> $CMD_LOG
$CMD

# Build up the command to configure the server
CMD=$(printf '%s setup -y --eula -u %s -p %s -f %s -l %s -e %s -o %s >> %s' $MARKETPLACE_CMD $USERNAME $PASSWORD $FIRSTNAME $LASTNAME $EMAILADDRESS $ORG $LOGFILE)
echo $CMD >> $CMD_LOG
$CMD
