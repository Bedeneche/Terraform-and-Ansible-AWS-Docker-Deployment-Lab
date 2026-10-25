terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.69.1"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_default_vpc" "server_vpc" {
  tags = {
    Name = "server_VPC"
  }
}

# Latest Ubuntu 22.04 AMI
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# Upload your public key to AWS
resource "aws_key_pair" "ansible" {
  key_name   = "ansible-lab-key"
  public_key = file("~/.ssh/ansible-lab.pub")
}

# Firewall rules
resource "aws_security_group" "ansible_lab" {
  name   = "ansible-lab-sg"
  vpc_id = aws_default_vpc.server_vpc.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]

  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Traffic between lab servers"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4 servers: 1 control + 3 managed
resource "aws_instance" "server" {
  count                  = 4
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ansible.key_name
  vpc_security_group_ids = [aws_security_group.ansible_lab.id]

  tags = {
    Name = count.index == 0 ? "ansible-control" : "ansible-node${count.index}"
  }
}

output "public_ips" {
  value = aws_instance.server[*].public_ip
}

output "private_ips" {
  value = aws_instance.server[*].private_ip
}
