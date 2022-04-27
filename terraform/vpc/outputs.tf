output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_a_id" {
  value = aws_subnet.public-subet-zone-a.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public-subet-zone-b.id
}

output "private_subnet_a_id" {
  value = aws_subnet.private-subet-zone-a.id
}

output "private_subnet_b_id" {
  value = aws_subnet.private-subet-zone-b.id
}



