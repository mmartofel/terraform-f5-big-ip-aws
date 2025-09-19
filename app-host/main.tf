# Following code helps to creaet an instance of:
# simple www server with dummy page that is willing to be presented via F5

# Specify the Terraform provider for AWS
provider "aws" {
  # region = "eu-central-1" # Change this to your preferred region
  region = "us-east-2" # Change this to your preferred region
}

# Create a VPC
resource "aws_vpc" "app-host-vpc" {
  cidr_block = "10.10.0.0/16"
  
  tags = {
    Name = "app-host-vpc"
    created-for = "APP-HOST"
  }
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "app-host-igw" {
  vpc_id = aws_vpc.app-host-vpc.id

  tags = {
    Name = "app-host-igw"
    created-for = "APP-HOST"
  }
}

# Create a Public Subnet
resource "aws_subnet" "app-host-subnet" {
  vpc_id                  = aws_vpc.app-host-vpc.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true                    # Assign public IPs automatically
  
  tags = {
    Name = "app-host-subnet"
    created-for = "APP-HOST"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "app-host-rt" {
  vpc_id = aws_vpc.app-host-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app-host-igw.id       # Route internet traffic to the IGW
  }

  tags = {
    Name = "app-host-rt"
    created-for = "APP-HOST"
  }
}

# Associate the Route Table with the Subnet (make it public)
resource "aws_route_table_association" "app-host-rta" {
  subnet_id      = aws_subnet.app-host-subnet.id
  route_table_id = aws_route_table.app-host-rt.id
}

# Create a Security Group that allows SSH
resource "aws_security_group" "app-host-sg" {
  name        = "app-host-security-group"
  description = "Allow SSH and HTTP inbound traffic for bastion host"
  vpc_id      = aws_vpc.app-host-vpc.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                     # Allow SSH from anywhere (not recommended for production)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                     # Allow HTTP from anywhere (if we test anything like httpd)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]                     # Allow for all outgoing traffic
  }

  tags = {
    Name = "app-host-sg"
    created-for = "APP-HOST"
  }    
}

# Generate a new SSH key pair
resource "tls_private_key" "app-host-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair using the generated public key
resource "aws_key_pair" "app-host-key-pair" {
  key_name   = "app-host-key"
  public_key = tls_private_key.app-host-key.public_key_openssh

  tags = {
    Name = "app-host-key-pair"
    created-for = "APP-HOST"
  }  
}

# Save the private key locally
resource "local_file" "private_key_file" {
  content  = tls_private_key.app-host-key.private_key_pem
  file_permission = "0600"
  filename = "app-host-key.pem"
}

# Create an EC2 instance in the public subnet
resource "aws_instance" "app-host-host" {
  # ami                          = "ami-00d7be712d19c601f"                # al2023-ami-2023.6.20250123.4-kernel-6.1-x86_64 (eu-central-1 region)
  ami                          = "ami-0d0f28110d16ee7d6"                # al2023-ami-2023.6.20250303.0-kernel-6.1-x86_64 (us-east-2 region)
  instance_type                = "t2.micro"                             # Free tier eligible
  subnet_id                    = aws_subnet.app-host-subnet.id           # Attach to subnet
  vpc_security_group_ids       = [aws_security_group.app-host-sg.id]     # Assign security group
  associate_public_ip_address  = true                                   # Attach a public IP
  key_name                     = aws_key_pair.app-host-key-pair.key_name # Attach the new key pair
  user_data                    = file("setup.sh")               # Path to your install script
  
  tags = {
    Name = "app-host-host"
    created-for = "APP-HOST"
  }
}

output "ssh_command" {
  value = "ssh -i app-host-key.pem ec2-user@${aws_instance.app-host-host.public_ip}"
}

output "web_url" {
  value = "http://${aws_instance.app-host-host.public_ip}"
}

