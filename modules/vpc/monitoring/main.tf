# SNS Topic for alerts
resource "aws_sns_topic" "ec2_alerts" {
  name = "${var.project_name}-ec2-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.ec2_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- CPU Utilization Alarm ---
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU above 80% for 4 minutes"
  alarm_actions       = [aws_sns_topic.ec2_alerts.arn]
  ok_actions          = [aws_sns_topic.ec2_alerts.arn]

  dimensions = {
    InstanceId = var.instance_id
  }
}

# --- EC2 Status Check Alarm ---
resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "${var.project_name}-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 instance status check failed"
  alarm_actions       = [aws_sns_topic.ec2_alerts.arn]

  dimensions = {
    InstanceId = var.instance_id
  }
}

# --- CloudWatch Dashboard ---
resource "aws_cloudwatch_dashboard" "ec2_health" {
  dashboard_name = "${var.project_name}-health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "CPU Utilization"
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_id]]
          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type = "metric"
        properties = {
          title  = "Status Check Failed"
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", var.instance_id]]
          period = 60
          stat   = "Maximum"
          view   = "timeSeries"
        }
      }
    ]
  })
}