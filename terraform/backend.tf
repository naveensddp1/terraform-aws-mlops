terraform {
  backend "s3" {
    bucket         = "mlops-naveen-rahil-terraform-source"
    key            = "terraform-statefile/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true 
    dynamodb_table = "terraform-state-lock-table" 
  }
}