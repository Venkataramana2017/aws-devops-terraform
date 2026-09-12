data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
data "aws_ssm_parameter" "ami" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
module "vpc" {
  source             = "../../modules/vpc"
  name               = var.name
  cidr_block         = var.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  subnets = {
    az1 = { availability_zone = data.aws_availability_zones.available.names[0], public_cidr = cidrsubnet(var.vpc_cidr, 8, 1), private_cidr = cidrsubnet(var.vpc_cidr, 8, 11) }
    az2 = { availability_zone = data.aws_availability_zones.available.names[1], public_cidr = cidrsubnet(var.vpc_cidr, 8, 2), private_cidr = cidrsubnet(var.vpc_cidr, 8, 12) }
  }
}
module "s3" {
  source      = "../../modules/s3"
  bucket_name = var.bucket_name
}
module "security_group" {
  source        = "../../modules/security-group"
  name          = "${var.name}-compute"
  vpc_id        = module.vpc.vpc_id
  ingress_rules = {}
  egress_rules = {
    https = { ip_protocol = "tcp", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0", description = "Outbound HTTPS" }
  }
}
module "ec2" {
  source               = "../../modules/ec2"
  name                 = "${var.name}-standalone"
  ami_id               = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ami[0].value
  subnet_id            = module.vpc.private_subnet_ids["az1"]
  security_group_ids   = [module.security_group.security_group_id]
  iam_instance_profile = var.iam_instance_profile
  instance_type        = var.instance_type
}
module "autoscaling" {
  source               = "../../modules/autoscaling"
  name                 = "${var.name}-workers"
  ami_id               = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ami[0].value
  subnet_ids           = values(module.vpc.private_subnet_ids)
  security_group_ids   = [module.security_group.security_group_id]
  capacity             = var.capacity
  iam_instance_profile = var.iam_instance_profile
  instance_type        = var.instance_type
}
