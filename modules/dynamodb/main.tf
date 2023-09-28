resource "aws_dynamodb_table" "this" {
  name           = var.table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = var.hash_key
  range_key      = var.range_key != null ? var.range_key : null
  stream_enabled = var.stream_enabled
  stream_view_type = var.stream_enabled ? var.stream_view_type : null

  dynamic "global_secondary_index" {
    for_each = var.create_gsi && var.range_key != null ? [1] : []
    content {
      name               = "${var.range_key}-Index"
      hash_key           = var.range_key
      read_capacity      = var.read_capacity
      write_capacity     = var.write_capacity
      projection_type    = "ALL"
    }
  }

  attribute {
    name = var.hash_key
    type = var.hash_key_type 
  }

  dynamic "attribute" {
    for_each = var.range_key != null ? [var.range_key] : []
    content {
      name = attribute.value
      type = var.range_key_type 
    }
  }

  server_side_encryption {
    enabled = true
  }


  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity
    ]
  }
}

resource "aws_appautoscaling_target" "read_target" {
  max_capacity       = var.read_max_capacity
  min_capacity       = var.read_min_capacity
  resource_id        = "table/${aws_dynamodb_table.this.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
  tags = var.tags
}

resource "aws_appautoscaling_policy" "read_policy" {
  name               = "${aws_dynamodb_table.this.name}-read-autoscale-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read_target.resource_id
  scalable_dimension = aws_appautoscaling_target.read_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.read_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.target_value
  }
}

resource "aws_appautoscaling_target" "write_target" {
  max_capacity       = var.write_max_capacity
  min_capacity       = var.write_min_capacity
  resource_id        = "table/${aws_dynamodb_table.this.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
  tags = var.tags
}

resource "aws_appautoscaling_policy" "write_policy" {
  name               = "${aws_dynamodb_table.this.name}-write-autoscale-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write_target.resource_id
  scalable_dimension = aws_appautoscaling_target.write_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.write_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.target_value
  }
}
