terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = "default"
}

# Create our S3 bucket (Datalake)
resource "aws_s3_bucket" "data-lake" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "data-lake" {
  bucket = aws_s3_bucket.data-lake.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "data-lake" {
  bucket = aws_s3_bucket.data-lake.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "data-lake-acl" {
   depends_on = [
    aws_s3_bucket_ownership_controls.data-lake,
    aws_s3_bucket_public_access_block.data-lake,
  ]
  bucket = aws_s3_bucket.data-lake.id
  acl    = "public-read-write"
}

# IAM role for EC2 to connect to AWS S3, & EMR
resource "aws_iam_role" "ec2_iam_role" {
  name = "ec2_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2"]
}

resource "aws_iam_instance_profile" "ec2_iam_role_instance_profile" {
  name = "ec2_iam_role_instance_profile"
  role = aws_iam_role.ec2_iam_role.name
}

# Create security group for access to EC2 from your Anywhere
resource "aws_security_group" "airflow_ec2_security_group" {
  name        = "airflow_ec2_security_group"
  description = "Security group to allow inbound SCP & outbound 8081 (Airflow) connections"

  ingress {
    description = "Inbound SCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "airflow_ec2_security_group"
  }
}

# Set up EMR
resource "aws_emr_cluster" "emr_cluster" {
  name                   = "emr_cluster"
  release_label          = "emr-6.9.0"
  applications           = ["Spark", "Hadoop"]
  scale_down_behavior    = "TERMINATE_AT_TASK_COMPLETION"
  service_role           = "EMR_DefaultRole"
  termination_protection = false
  auto_termination_policy {
    idle_timeout = var.auto_termination_timeoff
  }

  ec2_attributes {
    instance_profile = aws_iam_instance_profile.ec2_iam_role_instance_profile.id
  }


  master_instance_group {
    instance_type  = var.emr_instance_type
    instance_count = 1
    name           = "Master - 1"

    ebs_config {
      size                 = 32
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }

  core_instance_group {
    instance_type  = var.emr_instance_type
    instance_count = 2
    name           = "Core - 2"

    ebs_config {
      size                 = "32"
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }
}
# RSA key of size 4096 bits
resource "tls_private_key" "rsa_4096_airflow_ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "airflow_ec2_key" {
  key_name_prefix = var.key_name
  public_key      = tls_private_key.rsa_4096_airflow_ec2.public_key_openssh
}

data "aws_ami" "amazon-linux-2" {
 most_recent = true


 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}

resource "aws_instance" "airflow_ec2" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_iam_role_instance_profile.id
  key_name             = aws_key_pair.airflow_ec2_key.key_name
  security_groups      = [aws_security_group.airflow_ec2_security_group.name]

  tags = {
    Name = "airflow_ec2"
  }

  user_data = <<EOF

#!/bin/bash

echo 'Install git'

sudo yum -y update
sudo yum -y install git

echo 'Install docker and start docker service'

sudo yum install docker -y
sudo service docker start

echo 'making ec2-user to pass docker commands without using sudo'

sudo usermod -a -G docker ec2-user

echo 'Install docker compose manually'

sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod 666 /var/run/docker.sock

echo 'Clone git repo to EC2'

git clone https://github.com/taral-desai/Batch_emr_pipeline.git && cd airflow
mkdir -p ./dags ./logs ./plugins ./config

echo -e "AIRFLOW_UID=$(id -u)\nAIRFLOW_CONN_AWS_DEFAULT=aws://?region_name=${var.aws_region}\nAIRFLOW_VAR_EMR_ID=${aws_emr_cluster.sde_emr_cluster.id}\nAIRFLOW_VAR_BUCKET=${aws_s3_bucket.sde-data-lake.id}" >> .env

docker compose up airflow-init
docker compose up
echo "-------------------------START AIRFLOW SETUP---------------------------"

echo 'Start Airflow containers'

echo "-------------------------END AIRFLOW SETUP---------------------------"

EOF

}

# Setting as budget monitor, so we don't go over 10 USD per month
resource "aws_budgets_budget" "cost" {
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}
