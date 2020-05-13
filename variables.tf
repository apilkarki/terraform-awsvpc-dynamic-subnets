
/*=== VARIABLES ===*/

variable "region" {
  type = string
  description = "AWS region to launch resources."
  default = "us-east-1"
}

variable "aws_vpc" {
  type = map(string)
  description = "CIDR for vpc"
  default = {
    cidr_block                       = "10.0.0.0/16"
    enable_dns_hostnames             = true
    enable_dns_support               = true
  }
}

variable "instance_types" {
 description = "Type of EC2 instance to use"
 type    = map(string)
  default = {
   "dev" =  "t2.micro"
   "prod" = "t2.small"
 }
}

variable "aws_amis" {
  type = map(string)
  description = "ami according to region"
  default = {
    us-east-1 = "ami-039a49e70ea773ffc"
    eu-west-1 = "ami-674cbc1e"
    us-west-1 = "ami-969ab1f6"
    us-west-2 = "ami-8803e0f0"
  }
}

/*=== Not less than 2 because loadbalancer doesn't operate on single AZ. ===*/
variable "subnet_count" {
  type = number
  default = 2
}

/*=== Enable Private subnet along with Public subnet on a single AZ. ===*/
variable "enable_private_subnet" {
  type = bool
  description = "Option to enable private subnet"
  default = false
}

/*=== ELB Listener ===*/
variable "aws_lb_listener" {
  type = map(string)
  description = "Application LoadBalancer HTTP port"
  default = {
    port  = "800"
    protocol = "HTTP"
  # default_action_type = "forward"
  }
}

variable "aws_lb_target_group" {
  type = map(string)
  default = {
    load_balancing_algorithm_type = "round_robin"
    port                          = "80"
    protocol                      = "HTTP"
    slow_start                    = "0"
    hc_matcher                    = "200"
    hc_path                       = "/"
    hc_port                       = "80"
    hc_protocol                   = "HTTP" 
  }
}

/*=== VARIABLES ===*/
