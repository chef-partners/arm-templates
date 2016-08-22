
# Script to download, install and configure Chef Automate

# Command line parameters that are required in the script
# $1 - Automate License file
# $2 - Key for Chef Automate User
# $3 - Chef Server URL
# $4 - FQDN of the Automate Server
# $5 - Delivery Organisation Name

wget https://packages.chef.io/stable/ubuntu/14.04/delivery_0.5.125-1_amd64.deb
dpkg -i delivery_0.5.125-1_amd64.deb

delivery-ctl setup --license $1 --key $2 --server-url $3 --fqdn $4 -e "$5" --configure --no-build-node > /root/automate-setup.log