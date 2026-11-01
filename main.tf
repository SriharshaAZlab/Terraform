provider "aws" {
region = "eu-west-2"
}
#VPC- our own private network
#----------------------------------------
resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    
    tags = {
    Name = "my-vpc"
  }
}
#---------------------------------------
#Internet gateway - door to the internet
#-------------------------------------
resource "aws_internet_gateway" "my_igw" { 
 vpc_id = aws_vpc.my_vpc.id
 tags= {
    Name = "my_igw"
    }
}
#--------------------------------------------
#public subnet - whre ec2 will live
#------------------------------------------
resource "aws_subnet" "my_subnet" {
    vpc_id = aws_vpc.my_vpc.id
 cidr_block = "10.0.1.0/24"
 availability_zone = "eu-west-2a"
 map_public_ip_on_launch = true

  tags = {
   Name = "my-subnet"
 }
}
#--------------------------------------------
#RT
#-------------------------------------------------
resource "aws_route_table" "my_rt" {
    vpc_id = aws_vpc.my_vpc.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.my_igw.id
  }
 tags = {
  Name = "my-rt"
  }
}
#---------------------------------------
#Route table assosiation
#-----------------------------------
resource  "aws_route_table_association" "my_rt_assoc" {
 subnet_id = aws_subnet.my_subnet.id
 route_table_id = aws_route_table.my_rt.id
 }
#---------------------------------
#SG - allow the rule 
#--------------------------------
resource "aws_security_group" "my_sg" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
 ingress {
 description = "HTTP"
 from_port = 80
 to_port = 80
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]
}
 
 egress {
 from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"]
}
}
#---------------------------------------------
# EC2 vm Image 
#--------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# -----------------------------
# EC2 INSTANCE — the server that hosts our app
# -----------------------------
resource "aws_instance" "my_ec2" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.my_subnet.id
  vpc_security_group_ids      = [aws_security_group.my_sg.id]
  associate_public_ip_address = true

# This script runs automatically when the instance boots.
# It installs a web server and hosts a simple app (a webpage).
# Amazon Linux 2023 uses "dnf" instead of "yum".
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform-hosted EC2!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "my-app-server"
  }
}
# -----------------------------
# OUTPUT — show the public IP after apply
# -----------------------------
output "instance_public_ip" {
  value = aws_instance.my_ec2.public_ip
}
