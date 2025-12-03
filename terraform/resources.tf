resource "aws_dynamodb_table" "terraform_locks" {
     name         = "terraform-state-lock-table"
     billing_mode   = "PAY_PER_REQUEST"
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


data "aws_vpc" "default" { default = true }

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
    Name = "mlflow-security-group"
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-fullaccess-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach AmazonS3FullAccess managed policy
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


resource "aws_instance" "mlflow-server" {
    ami                 = data.aws_ami.amazon_linux_latest.id
    instance_type       = "t2.micro"
    key_name            = "mlflow-server-kp"
    vpc_security_group_ids = [aws_security_group.mlflow_sg.id]
    iam_instance_profile = aws_iam_role.ec2_s3_role.name
    tags = {            
    Name = "mlflow-server"
    Environment = "Dev"
    Owner = "Naveen-Rahil"
    }
    user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-devel gcc
    python3 -m ensurepip --upgrade
    pip3 install --user virtualenv mlflow boto3
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/ec2-user/.bashrc
    source /home/ec2-user/.bashrc
    mkdir -p /home/ec2-user/mlflow-data
    chown ec2-user:ec2-user /home/ec2-user/mlflow-data
    cat > /etc/systemd/system/mlflow.service <<'SERVICE'
    [Unit]
    Description=MLflow Server
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/home/ec2-user
    Environment=PATH=/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin
    ExecStart=/home/ec2-user/.local/bin/mlflow server \
        --backend-store-uri sqlite:///mlflow.db \
        --default-artifact-root s3://mlops-naveen-rahil-terraform-source/mlflow-artifacts \
        --host 0.0.0.0 --port 5000
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    SERVICE
    systemctl daemon-reload
    systemctl enable mlflow.service
    systemctl start mlflow.service
    EOF
}