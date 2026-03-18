terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # NOTE: This project uses local state for simplicity.
  # In production, migrate to an S3 remote backend:
  #
  # backend "s3" {
  #   bucket = "your-tf-state-bucket"
  #   key    = "ec2-static-site/terraform.tfstate"
  #   region = "ap-southeast-2"
  # }
}

provider "aws" {
  region = var.aws_region
}
