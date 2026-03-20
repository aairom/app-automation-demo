terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

# Create namespace
resource "kubernetes_namespace" "member_management" {
  metadata {
    name = "member-management"
    labels = {
      name = "member-management"
      app  = "member-management"
    }
  }
}

# Create ConfigMaps
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  data = {
    DATABASE_PATH                = "/data/members.db"
    PORT                         = "8080"
    VAULT_ADDR                   = "http://vault:8200"
    VAULT_MOUNT_POINT            = "secret"
    OTEL_EXPORTER_OTLP_ENDPOINT  = "http://otel-collector:4317"
  }
}

resource "kubernetes_config_map" "otel_collector_config" {
  metadata {
    name      = "otel-collector-config"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  data = {
    "otel-collector-config.yaml" = file("${path.module}/../otel-collector-config.yaml")
  }
}

resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  data = {
    "prometheus.yml" = file("${path.module}/../prometheus.yml")
  }
}

resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  data = {
    "datasources.yml" = file("${path.module}/../grafana-datasources.yml")
  }
}

# Create Secrets
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "app-secrets"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  data = {
    VAULT_TOKEN       = base64encode("dev-token")
    FLASK_SECRET_KEY  = base64encode("production-secret-key-change-me")
  }

  type = "Opaque"
}

# Create PersistentVolumeClaims
resource "kubernetes_persistent_volume_claim" "app_data" {
  metadata {
    name      = "app-data-pvc"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = "standard"
  }
}

resource "kubernetes_persistent_volume_claim" "prometheus_data" {
  metadata {
    name      = "prometheus-data-pvc"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
    storage_class_name = "standard"
  }
}

resource "kubernetes_persistent_volume_claim" "grafana_data" {
  metadata {
    name      = "grafana-data-pvc"
    namespace = kubernetes_namespace.member_management.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    storage_class_name = "standard"
  }
}