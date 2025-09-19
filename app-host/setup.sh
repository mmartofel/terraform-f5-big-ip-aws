#!/bin/bash
set -e

# Update the system
sudo yum update -y >> /var/log/install-tools.log 2>&1

# Install git
sudo yum install git -y >> /var/log/install-tools.log 2>&1
git --version >> /var/log/install-tools.log 2>&1

# Install httpd
sudo yum install -y httpd >> /var/log/install-tools.log 2>&1
sudo systemctl enable httpd >> /var/log/install-tools.log 2>&1
sudo systemctl start httpd >> /var/log/install-tools.log 2>&1
