# Vault Deployment
resource "kubernetes_deployment" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "vault"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vault"
      }
    }

    template {
      metadata {
        labels = {
          app = "vault"
        }
      }

      spec {
        container {
          name  = "vault"
          image = "hashicorp/vault:latest"

          port {
            container_port = 8200
            name           = "http"
          }

          env {
            name  = "VAULT_DEV_ROOT_TOKEN_ID"
            value = "dev-token"
          }

          env {
            name  = "VAULT_DEV_LISTEN_ADDRESS"
            value = "0.0.0.0:8200"
          }

          security_context {
            capabilities {
              add = ["IPC_LOCK"]
            }
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "vault"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 8200
      target_port = 8200
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app = "vault"
    }
  }
}

# OpenTelemetry Collector Deployment
resource "kubernetes_deployment" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "otel-collector"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "otel-collector"
      }
    }

    template {
      metadata {
        labels = {
          app = "otel-collector"
        }
      }

      spec {
        container {
          name  = "otel-collector"
          image = "otel/opentelemetry-collector-contrib:latest"
          args  = ["--config=/etc/otel-collector-config.yaml"]

          port {
            container_port = 4317
            name           = "otlp-grpc"
          }

          port {
            container_port = 4318
            name           = "otlp-http"
          }

          port {
            container_port = 8888
            name           = "metrics"
          }

          port {
            container_port = 8889
            name           = "prometheus"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/otel-collector-config.yaml"
            sub_path   = "otel-collector-config.yaml"
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.otel_collector_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "otel-collector"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 4317
      target_port = 4317
      protocol    = "TCP"
      name        = "otlp-grpc"
    }

    port {
      port        = 4318
      target_port = 4318
      protocol    = "TCP"
      name        = "otlp-http"
    }

    port {
      port        = 8888
      target_port = 8888
      protocol    = "TCP"
      name        = "metrics"
    }

    port {
      port        = 8889
      target_port = 8889
      protocol    = "TCP"
      name        = "prometheus"
    }

    selector = {
      app = "otel-collector"
    }
  }
}

# Prometheus Deployment
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"
          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles"
          ]

          port {
            container_port = 9090
            name           = "http"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus/prometheus.yml"
            sub_path   = "prometheus.yml"
          }

          volume_mount {
            name       = "data"
            mount_path = "/prometheus"
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "500m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "1000m"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.prometheus_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    type = "NodePort"

    port {
      port        = 9090
      target_port = 9090
      node_port   = 30090
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app = "prometheus"
    }
  }
}

# Grafana Deployment
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:latest"

          port {
            container_port = 3000
            name           = "http"
          }

          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = "admin"
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "admin"
          }

          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/grafana"
          }

          volume_mount {
            name       = "datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.grafana_data.metadata[0].name
          }
        }

        volume {
          name = "datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    type = "NodePort"

    port {
      port        = 3000
      target_port = 3000
      node_port   = 30030
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app = "grafana"
    }
  }
}

# Member Management App Deployment
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "member-management-app"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "member-management-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "member-management-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "member-management-app"
        }
      }

      spec {
        container {
          name              = "app"
          image             = "member-management-app:latest"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
            name           = "http"
          }

          env {
            name = "DATABASE_PATH"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "DATABASE_PATH"
              }
            }
          }

          env {
            name = "PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "PORT"
              }
            }
          }

          env {
            name = "VAULT_ADDR"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "VAULT_ADDR"
              }
            }
          }

          env {
            name = "VAULT_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app_secrets.metadata[0].name
                key  = "VAULT_TOKEN"
              }
            }
          }

          env {
            name = "VAULT_MOUNT_POINT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "VAULT_MOUNT_POINT"
              }
            }
          }

          env {
            name = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "OTEL_EXPORTER_OTLP_ENDPOINT"
              }
            }
          }

          env {
            name = "FLASK_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app_secrets.metadata[0].name
                key  = "FLASK_SECRET_KEY"
              }
            }
          }

          volume_mount {
            name       = "app-data"
            mount_path = "/data"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        volume {
          name = "app-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.app_data.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.vault,
    kubernetes_deployment.otel_collector
  ]
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "member-management-app"
    namespace = kubernetes_namespace.member_management.metadata[0].name
    labels = {
      app = "member-management-app"
    }
  }

  spec {
    type = "NodePort"

    port {
      port        = 8080
      target_port = 8080
      node_port   = 30080
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app = "member-management-app"
    }
  }
}