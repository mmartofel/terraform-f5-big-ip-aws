#!/bin/bash
set -e

# Update the system
sudo yum update -y >> /var/log/install-tools.log 2>&1

# Install git
sudo yum install git -y >> /var/log/install-tools.log 2>&1
git --version >> /var/log/install-tools.log 2>&1

# Install additional utilities and terraform
sudo yum install -y yum-utils shadow-utils >> /var/log/install-tools.log 2>&1
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo >> /var/log/install-tools.log 2>&1
sudo yum -y install terraform >> /var/log/install-tools.log 2>&1

# Install AWS CLI
sudo yum install aws-cli -y >> /var/log/install-tools.log 2>&1

# Install kubectl
curl -O -s https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.0/2024-12-20/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm ./kubectl
kubectl version --client=true >> /var/log/install-tools.log 2>&1

# Install eksctl
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo mv /tmp/eksctl /usr/local/bin

# Install httpd
sudo yum install -y httpd >> /var/log/install-tools.log 2>&1
sudo systemctl enable httpd >> /var/log/install-tools.log 2>&1
sudo systemctl start httpd >> /var/log/install-tools.log 2>&1
