resource "aws_dynamodb_table" "terraform_locks" {
     name         = "terraform-state-lock-table"
     hash_key     = "LockID"
     attribute {
        name = "LockID"
        type = "S"
    }
    tags = {
        Name        = "terraform-state-lock-table"
        Environment = "Dev" 
    }
}

data "aws_ami" "amazon_linux_latest" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] 
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"] 
  }
}

resource "aws_instance" "mlflow-server"{
    ami                 = data.aws_ami.amazon_linux_latest.id
    instance_type       = t2.micro
    key_name            = kp-mlflow-server
    tags = {            
    Name = "mlflow-server"
    Environment = "Dev"
    Owner = "Naveen-Rahil"
    }
    user_data = <<-EOF
    #!/bin/bash
    yum update -y 
    yum install -y python3 python3-pip
    pip install mlflow boto3
    mlflow server \
        --file-store sqlite:///mlflow.db \
        --default-artifact-root s3://mlops-naveen-rahil-terraform-source/mlflow-artifacts \
        --host 0.0.0.0 --port 5000
    EOF
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "mlflow_sg" {
  
  name        = "mlflow-security-group"
  description = "Allow HTTP, HTTPS , SSH , MLFLOW traffic"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

ingress {
    description = "Allow MLFLOW"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Represents all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-security-group"
  }
}
