terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "devsecops/vpc/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
