output "sns_topic_arn" {
  value = aws_sns_topic.ec2_alerts.arn
}

output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.ec2_health.dashboard_name}"
}