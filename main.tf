terraform{
    required_version = ">= 1.0.0"
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }   
}

provider "aws" {
    region = "us-east-1"
}

data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"] 

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    name = "rede-unifor"
  }
}

resource "aws_internet_gateway" "g_main" {
  vpc_id = aws_vpc.main.id
  tags = {
    name = "gw-rede-unifor"
  }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    tags = {
        Name = "subnet-rede-unifor-public"
    }
}

resource "aws_route_table" "r_public" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0" 
        gateway_id = aws_internet_gateway.g_main.id
    }
    tags = {
        Name = "internet-route"
    }
}

resource "aws_route_table_association" "a_public" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.r_public.id
  
}

resource "aws_security_group" "webserver" {
    name        = "webserver-aula-terraform"
    description = "permitir a porta 80 e 22 para acessar a web"
    vpc_id      = aws_vpc.main.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH Access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }   

    egress {
        description = "permitir todo o trafego de saida"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"] 
    }

    tags = {
        Name = "webserver-aula-terraform"
    }
}   

resource "aws_instance" "ec2_webserver" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.micro"
    subnet_id = aws_subnet.public.id
    key_name = "Projeto_final_key"
    security_groups = [aws_security_group.webserver.id]
    tags = {
        Name = "ec2-webserver-aula-terraform"
    }
  
}

resource "local_file" "ansible_inventory" {
  content  = <<-EOT
    [webserver]
    ${aws_instance.ec2_webserver.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=./projeto_final_key ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
  filename = "hosts.ini"
}

output "ec2_webserver_public_ip" {
    description = "Public IP da instancia EC2 Webserver"
    value = "http://${aws_instance.ec2_webserver.public_ip}"
}

output "cmd_ssh" {
    description = "Comando para acessar a instancia via SSH"
    value = "ssh ubuntu@${aws_instance.ec2_webserver.public_ip}"
  
}

