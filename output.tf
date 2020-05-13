output "availability_zones" {
  value = [data.aws_availability_zones.all.names]
}

output "vpc_cidr_block" {
  value = "${aws_vpc.my_vpc.cidr_block}"
}

/*output "private_subnet" {
  value = [for i in range(length(aws_subnet.my_subnet_private)) : "${aws_subnet.my_subnet_private[i].cidr_block}"]
}*/

output "private_subnet" {
  value = "${zipmap((aws_subnet.my_subnet_private.*.id), (aws_subnet.my_subnet_private.*.cidr_block))}"
}


/*output "public_subnet" {
  value = [for i in range(length(aws_subnet.my_subnet_public)) : "${aws_subnet.my_subnet_public[i].cidr_block}"]
}*/

output "public_subnet" {
  value = "${zipmap((aws_subnet.my_subnet_public.*.id), (aws_subnet.my_subnet_public.*.cidr_block))}"
}

/*output "public-subnet-ids" {
  value = "${join(",", aws_subnet.my_subnet_public.*.id)}"
}
*/

output "loadbalancer_dns" {
  value = "${aws_lb.my-nginx-lb.dns_name}"
}

/*output "private-subnet-ids" {
  value = "${join(",", aws_subnet.private-subnets.*.id)}"
}

*/
