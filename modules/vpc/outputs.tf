output "vpc_id" { value = aws_vpc.this.id }
output "vpc_cidr_block" { value = aws_vpc.this.cidr_block }
output "public_subnet_ids" { value = { for k, s in aws_subnet.public : k => s.id } }
output "private_subnet_ids" { value = { for k, s in aws_subnet.private : k => s.id } }
output "public_route_table_id" { value = aws_route_table.public.id }
output "private_route_table_ids" { value = { for k, r in aws_route_table.private : k => r.id } }
output "nat_gateway_ids" { value = { for k, n in aws_nat_gateway.this : k => n.id } }
