# Following code helps to creaet an instance of:
# F5 BIG-IP Virtual Edition - BEST (PAYG, 25Mbps)

# Specify the Terraform provider for AWS
provider "aws" {
  # region = "eu-central-1" # Change this to your preferred region
  region = "us-east-2" # Change this to your preferred region
}

# Create a VPC
resource "aws_vpc" "f5-bigip-vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "f5-bigip-vpc"
    created-for = "f5-bigip"
  }
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "f5-bigip-igw" {
  vpc_id = aws_vpc.f5-bigip-vpc.id

  tags = {
    Name = "f5-bigip-igw"
    created-for = "f5-bigip"
  }
}

# Create a Public Subnet
resource "aws_subnet" "f5-bigip-subnet" {
  vpc_id                  = aws_vpc.f5-bigip-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true                    # Assign public IPs automatically
  
  tags = {
    Name = "f5-bigip-subnet"
    created-for = "f5-bigip"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "f5-bigip-rt" {
  vpc_id = aws_vpc.f5-bigip-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.f5-bigip-igw.id       # Route internet traffic to the IGW
  }

  tags = {
    Name = "f5-bigip-rt"
    created-for = "f5-bigip"
  }
}

# Associate the Route Table with the Subnet (make it public)
resource "aws_route_table_association" "f5-bigip-rta" {
  subnet_id      = aws_subnet.f5-bigip-subnet.id
  route_table_id = aws_route_table.f5-bigip-rt.id
}

# Create a Security Group that allows SSH and HTTPS access
resource "aws_security_group" "f5-bigip-sg" {
  name        = "f5-bigip-security-group"
  description = "Allow SSH inbound traffic for f5-bigip host"
  vpc_id      = aws_vpc.f5-bigip-vpc.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                     # Allow SSH from anywhere (not recommended for production)
  }
  
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                     # Allow admin console HTTPS access from anywhere (not recommended for production)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "f5-bigip-sg"
    created-for = "f5-bigip"
  }    
}

# Generate a new SSH key pair
resource "tls_private_key" "f5-bigip-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair using the generated public key
resource "aws_key_pair" "f5-bigip-key-pair" {
  key_name   = "f5-bigip-key"
  public_key = tls_private_key.f5-bigip-key.public_key_openssh

  tags = {
    Name = "f5-bigip-key-pair"
    created-for = "f5-bigip"
  }  
}

# Save the private key locally
resource "local_file" "private_key_file" {
  content  = tls_private_key.f5-bigip-key.private_key_pem
  file_permission = "0600"
  filename = "f5-bigip-key.pem"
}

# Create an EC2 instance in the public subnet
resource "aws_instance" "f5-bigip-host" {
  # Be aware that AMI id is region speciffic, please change if you install at the other region
  ami                          = "ami-08583ffbb1c2fde51"                # F5 BIGIP-17.5.1.2-0.0.5 PAYG-Good 25Mbps-250916013626 (us-east-2)
  instance_type                = "m5.xlarge"                             # Free tier eligible
  subnet_id                    = aws_subnet.f5-bigip-subnet.id           # Attach to subnet
  vpc_security_group_ids       = [aws_security_group.f5-bigip-sg.id]     # Assign security group
  associate_public_ip_address  = true                                   # Attach a public IP
  key_name                     = aws_key_pair.f5-bigip-key-pair.key_name # Attach the new key pair
  
  tags = {
    Name = "f5-bigip-host"
    created-for = "f5-bigip"
  }
}

output "ssh_command" {
  value = "ssh -i f5-bigip-key.pem admin@${aws_instance.f5-bigip-host.public_ip}"
}

output "web_url" {
  value = "https://${aws_instance.f5-bigip-host.public_ip}:8443"
}
