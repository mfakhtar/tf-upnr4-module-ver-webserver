provider "aws" {
  region = var.region
}

module "webserver_cluster" {
  source = "github.com/mfakhtar/tf-upnr4-module-ver?ref=v0.0.1"

  cluster_name           = "webservers-stage"
  db_remote_state_bucket = "fawaz-terraform-up-and-running-state"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

  instance_type = "t3.micro"
  min_size      = 1
  max_size      = 2
}

resource "aws_security_group_rule" "allow_testing_inbound" {
  type              = "ingress"
  security_group_id = module.webserver_cluster.alb_security_group_id

  from_port   = 12345
  to_port     = 12345
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}