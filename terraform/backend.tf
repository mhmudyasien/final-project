# backend.tf

# Example configuration for remote state management
# PRE-REQUISITE: S3 Bucket and DynamoDB Table must exist
/*
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "capstone/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
*/
