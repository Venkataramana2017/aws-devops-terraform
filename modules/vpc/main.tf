locals {
  nat_subnets = var.enable_nat_gateway ? (var.single_nat_gateway ? { (sort(keys(var.subnets))[0]) = var.subnets[sort(keys(var.subnets))[0]] } : var.subnets) : {}
}
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.name })
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}
resource "aws_subnet" "public" {
  for_each                = var.subnets
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.name}-public-${each.key}", Tier = "public" })
}
resource "aws_subnet" "private" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.private_cidr
  tags              = merge(var.tags, { Name = "${var.name}-private-${each.key}", Tier = "private" })
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route_table_association" "public" {
  for_each       = var.subnets
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  for_each = local.nat_subnets
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })
}
resource "aws_nat_gateway" "this" {
  for_each      = local.nat_subnets
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })
  depends_on    = [aws_internet_gateway.this]
}
resource "aws_route_table" "private" {
  for_each = var.subnets
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}
resource "aws_route" "nat" {
  for_each               = var.enable_nat_gateway ? var.subnets : {}
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? sort(keys(var.subnets))[0] : each.key].id
}
resource "aws_route_table_association" "private" {
  for_each       = var.subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
data "aws_region" "current" {}
resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_s3_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], [for rt in aws_route_table.private : rt.id])
  tags              = merge(var.tags, { Name = "${var.name}-s3" })
}
