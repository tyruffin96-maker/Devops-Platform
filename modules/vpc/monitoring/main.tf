resource "aws_cloudwatch_dashboard" "ec2_health" {
  dashboard_name = "${var.project_name}-health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "CPU Utilization"
          region  = var.aws_region
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_id]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
          annotations = {
            horizontal = []
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Status Check Failed"
          region  = var.aws_region
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", var.instance_id]]
          period  = 60
          stat    = "Maximum"
          view    = "timeSeries"
          annotations = {
            horizontal = []
          }
        }
      }
    ]
  })
}