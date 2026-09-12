output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
output "bucket_name" { value = module.s3.bucket_id }
output "instance_id" { value = module.ec2.instance_id }
output "instance_private_ip" { value = module.ec2.private_ip }
output "security_group_id" { value = module.security_group.security_group_id }
output "autoscaling_group_name" { value = module.autoscaling.autoscaling_group_name }
