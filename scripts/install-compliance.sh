wget https://packages.chef.io/stable/ubuntu/14.04/chef-compliance_1.3.1-1_amd64.deb
dpkg -i chef-compliance_1.3.1-1_amd64.deb
chef-compliance-ctl reconfigure
