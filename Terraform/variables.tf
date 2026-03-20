variable "minikube_context" {
  description = "Kubernetes context for Minikube"
  type        = string
  default     = "minikube"
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "member-management"
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 2
}

variable "vault_token" {
  description = "Vault root token for development"
  type        = string
  default     = "dev-token"
  sensitive   = true
}

variable "flask_secret_key" {
  description = "Flask secret key"
  type        = string
  default     = "production-secret-key-change-me"
  sensitive   = true
}