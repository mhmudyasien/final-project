terraform {
  backend "s3" {
    bucket         = "capstone-project-tf-state-1770757198"
    key            = "final-project/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
