output "namespace" {
  description = "The namespace where resources are deployed"
  value       = kubernetes_namespace.member_management.metadata[0].name
}

output "app_url" {
  description = "URL to access the Member Management application"
  value       = "http://$(minikube ip):30080"
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://$(minikube ip):30090"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://$(minikube ip):30030"
}

output "grafana_credentials" {
  description = "Grafana login credentials"
  value = {
    username = "admin"
    password = "admin"
  }
  sensitive = true
}