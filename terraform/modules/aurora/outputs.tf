output "cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.aurora_cluster.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora_cluster.reader_endpoint
}

output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.aurora_cluster.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.aurora_cluster.arn
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_rds_cluster.aurora_cluster.database_name
}

output "security_group_id" {
  description = "Security group ID for Aurora"
  value       = aws_security_group.aurora_sg.id
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.aurora_cluster.port
}