/*=== Specify the provider and access details ===*/  
provider "aws" {
  region = var.region
  profile = "default"
}

data "aws_availability_zones" "all" {
  state = "available"
}

locals {
   subnet_count = var.subnet_count >= 2 ? var.subnet_count : length(data.aws_availability_zones.all.names)
}

/*=== Create a VPC to launch our resources ===*/ 
resource "aws_vpc" "my_vpc" {
  cidr_block                       = var.aws_vpc["cidr_block"]
  enable_classiclink               = false
  enable_classiclink_dns_support   = false
  enable_dns_hostnames             = var.aws_vpc["enable_dns_hostnames"]
  enable_dns_support               = var.aws_vpc["enable_dns_support"]
  tags                             = {
      "Name" = "my_vpc"
  }
}

/*=== Create a private subnet to launch our web-app-instances ===*/
resource "aws_subnet" "my_subnet_private" {
  vpc_id                   = aws_vpc.my_vpc.id
  count                    = var.enable_private_subnet == true ? local.subnet_count : 0
  cidr_block               = cidrsubnet(aws_vpc.my_vpc.cidr_block, local.subnet_count, count.index)
  tags = { 
    Name = format("%s%d%s","private-",count.index,"-${aws_vpc.my_vpc.tags["Name"]}")
    type = "private" 
  }
  availability_zone       =  "${data.aws_availability_zones.all.names[count.index]}"
}

/*=== Create a public subnet to launch our webserver-instances ===*/
resource "aws_subnet" "my_subnet_public" {
  vpc_id                   =  aws_vpc.my_vpc.id
  count                    =  local.subnet_count
  cidr_block               =  cidrsubnet(aws_vpc.my_vpc.cidr_block, local.subnet_count, length(aws_subnet.my_subnet_private) + count.index)
  map_public_ip_on_launch  =  true
  tags = {
    Name = format("%s%d%s","public-",count.index,"-${aws_vpc.my_vpc.tags["Name"]}") 
    type = "public" 
  }
  availability_zone       =  "${data.aws_availability_zones.all.names[count.index]}"
}

/*=== Create an igw to provide our public subnet access to the outer world ===*/
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = { 
    Name = "my_igw" 
  }
}

/*=== Create Private route table for private subnets ===*/# 
resource "aws_route_table" "my_private_RT" {
  vpc_id = aws_vpc.my_vpc.id
  tags = { 
    Name = "my_private_RT" 
  }
  depends_on        =  [aws_subnet.my_subnet_private]
}

/*=== Grant the VPC internet access on its public subnets ===*/
resource "aws_route_table" "my_public_RT" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block             = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.my_igw.id
  } 
  tags = { 
    Name = "my_public_RT" 
  }
  depends_on        =  [aws_subnet.my_subnet_public]
}

/*===  ===*/
resource "aws_route_table_association" "private" {
  count             = length(aws_subnet.my_subnet_private) #!= 0 ? length(aws_subnet.my_subnet_private) : 0
  subnet_id         = "${aws_subnet.my_subnet_private[count.index].id}"
  route_table_id    =  aws_route_table.my_private_RT.id
  depends_on        =  [aws_subnet.my_subnet_private]
}

/*=== Grant the VPC internet access on its public subnets ===*/
resource "aws_route_table_association" "public" {
  count             =  length(aws_subnet.my_subnet_public)
  subnet_id         = "${aws_subnet.my_subnet_public[count.index].id}"
  route_table_id    =  aws_route_table.my_public_RT.id
  depends_on        =  [aws_subnet.my_subnet_public]
}

/*=== LoadBalancer ===*/
resource "aws_lb" "my-nginx-lb" {
  name                       = "my-nginx-lb"
  drop_invalid_header_fields = false
  enable_deletion_protection = false
  enable_http2               = true
  idle_timeout               = 60
  internal                   = false
  ip_address_type            = "ipv4"
  load_balancer_type         = "application"
  security_groups            = ["${aws_security_group.my-vpc-lb-sec.id}"]
  subnets                    = [for i in range(length(aws_subnet.my_subnet_public)) : "${aws_subnet.my_subnet_public[i].id}"]
  tags                       = {}
  /*  access_logs {
        enabled = false
    }*/

  timeouts {
      delete = "2m"
  }
}

resource "aws_lb_listener" "my-nginx-listener" {
  load_balancer_arn        = "${aws_lb.my-nginx-lb.arn}"
  port                     = var.aws_lb_listener["port"]
  protocol                 = var.aws_lb_listener["protocol"]
  default_action { 
    type                   = "forward"
    target_group_arn       = "${aws_lb_target_group.my-nginx-tg.arn}"
  }
}

/*=== Security group for the ELB ===*/
resource "aws_security_group" "my-vpc-lb-sec" {
  name        = "my-vpc-lb-sec"
  description = "Allow HTTP inbound traffic"
  revoke_rules_on_delete = true
  vpc_id      = "${aws_vpc.my_vpc.id}"

  /*=== Allow inbound HTTP traffic from internet ===*/# 
  ingress {
    description = "HTTP from internet"
    from_port   = 800
    to_port     = 800
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
  /*=== Allow outbound to web-instance ===*/
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups   = ["${aws_security_group.my-vpc-ec2-sec.id}"]
  }

  tags = {
    Type = "allow_http"
  }
  timeouts {
      delete = "2m"
  }
}

resource "aws_lb_target_group" "my-nginx-tg" {
  name                          = "my-nginx-tg"
  deregistration_delay          = "300"
  load_balancing_algorithm_type = var.aws_lb_target_group["load_balancing_algorithm_type"]
  port                          = var.aws_lb_target_group["port"]
  protocol                      = var.aws_lb_target_group["protocol"]
  slow_start                    = var.aws_lb_target_group["slow_start"]
  tags                          = {}
  target_type                   = "instance"
  vpc_id                        = aws_vpc.my_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = var.aws_lb_target_group["hc_matcher"]
    path                = var.aws_lb_target_group["hc_path"]
    port                = var.aws_lb_target_group["hc_port"]
    protocol            = var.aws_lb_target_group["hc_protocol"]
    timeout             = 5
    unhealthy_threshold = 2
  }

  stickiness {
    cookie_duration = 86400
    enabled         = false
    type            = "lb_cookie"
  }
}

/*=== Launch template/configuration to be used by ASG ===*/
resource "aws_launch_template" "my_launch_temp" {
  name_prefix             = "my_launch_temp"
  description             = "nginx-webserver-launch-template"
  disable_api_termination = false
  image_id                = "${lookup(var.aws_amis, var.region)}"
  instance_type           = "${var.instance_types["dev"]}"
  vpc_security_group_ids    = ["${aws_security_group.my-vpc-ec2-sec.id}"]
  key_name                = "ec2"
  user_data = filebase64("nginx.sh")
  tags                    = {}
  tag_specifications {
    resource_type = "instance"
    tags          = {
        "Name" = "nginx-webserver-asg"
        "Type" = "nginx-webserver-launch-template"
    }
  }
}

/*=== AutoScalingGroup Definition ===*/
resource "aws_autoscaling_group" "my-asg" {
  name                      = "my-asg"
  default_cooldown          = 300
  desired_capacity          = length(aws_subnet.my_subnet_public)
  #force_delete              = true
  enabled_metrics           = []
  health_check_grace_period = 60
  health_check_type         = "ELB"
  load_balancers            = []
  max_instance_lifetime     = 0
  min_size                  = 1
  max_size                  = length(aws_subnet.my_subnet_public) + 2
  metrics_granularity       = "1Minute"
  protect_from_scale_in     = false
  suspended_processes       = []
  target_group_arns         = ["${aws_lb_target_group.my-nginx-tg.arn}"]
  termination_policies      = []
  vpc_zone_identifier       = [for i in range(length(aws_subnet.my_subnet_public)) : "${aws_subnet.my_subnet_public[i].id}"] 

  launch_template {
    id      = "${aws_launch_template.my_launch_temp.id}"
    version = "$Latest"
  }

  timeouts {
      delete = "2m"
  }
}

/*=== NACL for public subnet ===*/
resource "aws_network_acl" "my-vpc-nacl" {
  vpc_id = "${aws_vpc.my_vpc.id}"
  subnet_ids = [for i in range(local.subnet_count) : "${aws_subnet.my_subnet_public[i].id}"]

  /*===  ===*/
  ingress {
    protocol    = "tcp"
    rule_no     = 10
    action     = "allow"
    cidr_block = "0.0.0.0/0" /*=== Your trusted IP address range ===*/
    from_port   = 22
    to_port     = 22
  }

  /*=== ELB listener port ===*/
  ingress {
    protocol    = "tcp"
    rule_no     =  20
    action      = "allow"
    cidr_block  = "0.0.0.0/0"
    from_port   = 800
    to_port     = 800
  }

  /*=== Instance listener port ===*/
  ingress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  
  /*=== Allow inbound return traffic from hosts on the internet that are responding to requests originating in the subnet. ===*/ 
  ingress {
    protocol   = "tcp"
    rule_no    = 40
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  /*=== Allow all outbound traffic on the ephemeral ports ===*/ 
  egress {
    protocol   = "tcp"
    rule_no    = 40
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 65535
  }

  /*=== Allow outbound responses to clients on the internet ===*/ 
  egress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }


  tags = {
    Name = "my-vpc-nacl-pub"
  }
}

/*=== Security group to access the instances over SSH and HTTP ===*/
resource "aws_security_group" "my-vpc-ec2-sec" {
  name        = "my-vpc-ec2-sec"
  description = "ec2 sg for ssh & http"
  revoke_rules_on_delete = true
  vpc_id      = "${aws_vpc.my_vpc.id}"

  /*===  ===*/ 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0","${aws_vpc.my_vpc.cidr_block}"] /*=== Your trusted IP address range ===*/
  }

  /*=== HTTP access from the VPC ===*/
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    self        = true
    cidr_blocks = ["${aws_vpc.my_vpc.cidr_block}"]
  }

  /*=== Outbound  ===*/# 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Type = "allow_22_80"
  }
}