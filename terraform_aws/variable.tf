## AWS account level config: region
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
## AWS S3 bucket details
variable "bucket_prefix" {
  description = "Bucket prefix for our datalake"
  type        = string
  default     = "data-lake-"
}

## Key to allow connection to our EC2 instance
variable "key_name" {
  description = "EC2 key name"
  type        = string
  default     = "airflow_ec2_key"
}

variable "instance_type" {
  description = "Instance type EC2"
  type        = string
  default     = "t2.xlarge"
}

variable "emr_instance_type" {
  description = "Instance type for EMR"
  type        = string
  default     = "m4.xlarge"
}

variable "auto_termination_timeoff" {
  description = "Auto EMR termination time(in idle seconds)"
  type        = number
  default     = 14400 # 4 hours
}