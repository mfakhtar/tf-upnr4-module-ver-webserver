output "asg_name" {
  value       = aws_autoscaling_group.fawaz-asg.name
  description = "The name of the Auto Scaling Group"
}

output "alb_dns_name" {
  value       = aws_lb.fawaz-asg-lb.dns_name
  description = "The domain name of the load balancer"
}

output "alb_security_group_id" {
  value       = aws_security_group.tf-upnr-fawaz-asg-lb.id
  description = "The ID of the Security Group attached to the load balancer"
}