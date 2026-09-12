resource "aws_launch_template" "this" {
  name_prefix            = "${var.name}-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.security_group_ids
  user_data              = var.user_data == null ? null : base64encode(var.user_data)
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile == null ? [] : [var.iam_instance_profile]
    content {
      name = iam_instance_profile.value
    }
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  block_device_mappings {
    device_name = var.root_device_name
    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }
  monitoring {
    enabled = true
  }
  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume"])
    content {
      resource_type = tag_specifications.value
      tags          = merge(var.tags, { Name = var.name })
    }
  }
  tags = var.tags
}
resource "aws_autoscaling_group" "this" {
  name_prefix               = "${var.name}-"
  min_size                  = var.capacity.min
  desired_capacity          = var.capacity.desired
  max_size                  = var.capacity.max
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_group_arns
  health_check_type         = var.health_check_type
  health_check_grace_period = 300
  default_instance_warmup   = 300
  launch_template {
    id      = aws_launch_template.this.id
    version = tostring(aws_launch_template.this.latest_version)
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
    }
  }
  dynamic "tag" {
    for_each = merge(var.tags, { Name = var.name })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    ignore_changes = [desired_capacity]
    precondition {
      condition     = var.health_check_type != "ELB" || length(var.target_group_arns) > 0
      error_message = "ELB health checks require target_group_arns."
    }
  }
}
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}
