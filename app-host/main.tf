# Specify the Terraform provider for AWS
provider "aws" {
  # region = "eu-central-1" # Change this to your preferred region
  region = "us-east-2" # Change this to your preferred region
}

# Create a VPC
resource "aws_vpc" "bastion-vpc" {
  cidr_block = "10.10.0.0/16"
  
  tags = {
    Name = "bastion-vpc"
    created-for = "BASTION"
  }
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "bastion-igw" {
  vpc_id = aws_vpc.bastion-vpc.id

  tags = {
    Name = "bastion-igw"
    created-for = "BASTION"
  }
}

# Create a Public Subnet
resource "aws_subnet" "bastion-subnet" {
  vpc_id                  = aws_vpc.bastion-vpc.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true                    # Assign public IPs automatically
  
  tags = {
    Name = "bastion-subnet"
    created-for = "BASTION"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "bastion-rt" {
  vpc_id = aws_vpc.bastion-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bastion-igw.id       # Route internet traffic to the IGW
  }

  tags = {
    Name = "bastion-rt"
    created-for = "BASTION"
  }
}

# Associate the Route Table with the Subnet (make it public)
resource "aws_route_table_association" "bastion-rta" {
  subnet_id      = aws_subnet.bastion-subnet.id
  route_table_id = aws_route_table.bastion-rt.id
}

# Create a Security Group that allows SSH
resource "aws_security_group" "bastion-sg" {
  name        = "bastion-security-group"
  description = "Allow SSH and HTTP inbound traffic for bastion host"
  vpc_id      = aws_vpc.bastion-vpc.id
  
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
    Name = "bastion-sg"
    created-for = "BASTION"
  }    
}

# Generate a new SSH key pair
resource "tls_private_key" "bastion-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair using the generated public key
resource "aws_key_pair" "bastion-key-pair" {
  key_name   = "bastion-key"
  public_key = tls_private_key.bastion-key.public_key_openssh

  tags = {
    Name = "bastion-key-pair"
    created-for = "BASTION"
  }  
}

# Save the private key locally
resource "local_file" "private_key_file" {
  content  = tls_private_key.bastion-key.private_key_pem
  file_permission = "0600"
  filename = "bastion-key.pem"
}

# Create an EC2 instance in the public subnet
resource "aws_instance" "bastion-host" {
  # ami                          = "ami-00d7be712d19c601f"                # al2023-ami-2023.6.20250123.4-kernel-6.1-x86_64 (eu-central-1 region)
  ami                          = "ami-0d0f28110d16ee7d6"                # al2023-ami-2023.6.20250303.0-kernel-6.1-x86_64 (us-east-2 region)
  instance_type                = "t2.micro"                             # Free tier eligible
  subnet_id                    = aws_subnet.bastion-subnet.id           # Attach to subnet
  vpc_security_group_ids       = [aws_security_group.bastion-sg.id]     # Assign security group
  associate_public_ip_address  = true                                   # Attach a public IP
  key_name                     = aws_key_pair.bastion-key-pair.key_name # Attach the new key pair
  user_data                    = file("install-tools.sh")               # Path to your install script
  
  tags = {
    Name = "bastion-host"
    created-for = "BASTION"
  }
}

output "ssh_command" {
  value = "ssh -i bastion-key.pem ec2-user@${aws_instance.bastion-host.public_ip}"
}
