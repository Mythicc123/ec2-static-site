variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2" # Sydney — closest to you in Ultimo, NSW
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # Free tier eligible
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID for ap-southeast-2"
  type        = string
  default     = "ami-0310483fb2b488153" # Ubuntu 22.04 LTS in ap-southeast-2 (verify before use)
}

variable "key_pair_name" {
  description = "Name of the existing EC2 Key Pair in AWS for SSH access"
  type        = string
  # Set this in terraform.tfvars (which is gitignored)
  # e.g. key_pair_name = "my-ec2-key"
}

variable "domain_name" {
  description = "Your registered domain name (used for Route 53 + HTTPS)"
  type        = string
  default     = "" # Leave empty to skip DNS/HTTPS setup
}

variable "project_name" {
  description = "Tag prefix applied to all AWS resources"
  type        = string
  default     = "ec2-static-site"
}
