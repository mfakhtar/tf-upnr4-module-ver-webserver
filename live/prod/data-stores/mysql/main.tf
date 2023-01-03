provider "aws" {
  region = var.region
}

resource "aws_db_instance" "example" {
  identifier_prefix   = "prod-fawaz-terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t2.micro"
  skip_final_snapshot = true
  db_name             = "prod_fawaz_example_database"

  # How should we set the username and password?
  username = var.db_username
  password = var.db_password
}

terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "fawaz-terraform-up-and-running-state"
    key            = "stage/data-stores/mysql/terraform.tfstate"
    region         = "ap-south-1"

    # Replace this with your DynamoDB table name!
    dynamodb_table = "fawaz-terraform-up-and-running-locks"
    encrypt        = true
  }
}