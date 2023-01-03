locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
#    bucket = "fawaz-terraform-up-and-running-state"
#    key    = "stage/data-stores/mysql/terraform.tfstate"
    bucket = var.db_remote_state_bucket
    key = var.db_remote_state_key
    region = var.region
  }
}

data "aws_vpc" "mum-default-vpc" {
  default = true
}

data "aws_subnets" "mum-default-subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.mum-default-vpc.id]

  }
    filter {
    name   = "default-for-az"
    values = [true]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "tf-upnr-fawaz-sg" {
    name = "${var.cluster_name}-sg"

    ingress {
      from_port = local.http_port
      to_port = local.http_port
      protocol = local.tcp_protocol
      cidr_blocks = local.all_ips
    }

     ingress {
      from_port = var.server_port
      to_port = var.server_port
      protocol = local.tcp_protocol
      cidr_blocks = local.all_ips
    }


    ingress {
      from_port = "22"
      to_port = "22"
      protocol = local.tcp_protocol
      cidr_blocks = ["49.36.222.156/32"]
    }
}

resource "aws_launch_configuration" "fawaz-webserver-lc" {
  image_id = "ami-07ffb2f4d65357b42"
  instance_type = var.instance_type
  key_name = "fawaz-mum"
  security_groups = [ aws_security_group.tf-upnr-fawaz-sg.id ]
  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })
# Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }  
  
}

resource "aws_autoscaling_group" "fawaz-asg" {
  launch_configuration = aws_launch_configuration.fawaz-webserver-lc.name
  vpc_zone_identifier = data.aws_subnets.mum-default-subnets.ids

  target_group_arns = [ aws_lb_target_group.asg-target.arn ]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key = "Name"
    value = "fawaz-terraform-eg-asg"
    propagate_at_launch = true
  }
  
}

resource "aws_lb" "fawaz-asg-lb" {
  name = "${var.cluster_name}-lb"
  load_balancer_type = "application"
  subnets = data.aws_subnets.mum-default-subnets.ids
  security_groups = [ aws_security_group.tf-upnr-fawaz-asg-lb.id ]
}

resource "aws_lb_listener" "fawaz-asg-lb-listner" {
  load_balancer_arn = aws_lb.fawaz-asg-lb.arn
  port = local.http_port
  protocol = "HTTP"

  default_action {
    type = "fixed-response"      

  fixed_response {
    content_type = "text/plain"
    message_body = "404: page not found"
    status_code  = 404
    }
  }
}

resource "aws_security_group" "tf-upnr-fawaz-asg-lb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tf-upnr-fawaz-asg-lb.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.tf-upnr-fawaz-asg-lb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

resource "aws_lb_target_group" "asg-target" {
  name = "${var.cluster_name}-asg-target"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.mum-default-vpc.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
  
}

resource "aws_lb_listener_rule" "lb-asg-listner-rule" {
  listener_arn = aws_lb_listener.fawaz-asg-lb-listner.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg-target.arn
  }  
}