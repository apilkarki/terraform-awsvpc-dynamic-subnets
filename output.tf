output "availability_zones" {
  value = [data.aws_availability_zones.all.names]
}

output "vpc_cidr_block" {
  value = "${aws_vpc.my_vpc.cidr_block}"
}

output "private_subnet" {
  value = "${zipmap((aws_subnet.my_subnet_private.*.id), (aws_subnet.my_subnet_private.*.cidr_block))}"
}

output "public_subnet" {
  value = "${zipmap((aws_subnet.my_subnet_public.*.id), (aws_subnet.my_subnet_public.*.cidr_block))}"
}

output "loadbalancer_dns" {
  value = "${aws_lb.my-nginx-lb.dns_name}"
}
