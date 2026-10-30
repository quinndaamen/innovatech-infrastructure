output "elasticsearch_instance_id" {
  description = "EC2 instance ID for Elasticsearch"
  value       = aws_instance.elasticsearch.id
}

output "elasticsearch_private_ip" {
  description = "Private IP address of Elasticsearch"
  value       = aws_instance.elasticsearch.private_ip
}

output "logstash_instance_id" {
  description = "EC2 instance ID for Logstash"
  value       = aws_instance.logstash.id
}

output "logstash_private_ip" {
  description = "Private IP address of Logstash"
  value       = aws_instance.logstash.private_ip
}

output "kibana_instance_id" {
  description = "EC2 instance ID for Kibana"
  value       = aws_instance.kibana.id
}

output "kibana_private_ip" {
  description = "Private IP address of Kibana"
  value       = aws_instance.kibana.private_ip
}

output "elastic_packages_bucket_name" {
  description = "S3 bucket containing Elastic Stack installation packages"
  value       = aws_s3_bucket.elastic_packages.id
}