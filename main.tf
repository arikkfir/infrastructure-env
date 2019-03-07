terraform {
  required_version = "= 0.11.11"
  backend "gcs" {
    project = "arikkfir"
    bucket  = "arikkfir-terraform"
  }
}

// Environment being set up
variable "env" {}
variable "region" {}
variable "zone" {}

// Cloudflare credentials
variable "cloudflare_email" {}
variable "cloudflare_token" {}

// GKE details
variable "gke_admin" {}
variable "gke_master_password" {}
variable "gke_master_username" {}
variable "gke_version" {
  default = "1.11.7-gke.6"
}

// Security
variable "ip_address_whitelist" {
  type = "list"
}

// ACME
variable "letsencrypt_account_email" {}
variable "letsencrypt_url" {}

// Monitoring
variable "alertmanager_slack_url" {}
variable "grafana_admin_password" {}
variable "grafana_db_root_password" {}
variable "grafana_db_user_password" {}
variable "kubewatch_slack_token" {}

// Required GCP APIs
variable "gcp_project_apis" {
  type    = "list"
  default = [
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com"
  ]
}

// Providers
provider "local" {
  version = "~> 1.1"
}
provider "template" {
  version = "~> 2.1"
}
provider "google" {
  version = "~> 2.0.0"
}
provider "google-beta" {
  version = "~> 2.0.0"
}
data "google_project" "arikkfir" {
  provider = "google-beta"
}
provider "cloudflare" {
  version = "~> 1.11"
  email   = "${var.cloudflare_email}"
  token   = "${var.cloudflare_token}"
}

// Setup GCP project
resource "google_project_service" "apis" {
  count                      = "${length(var.gcp_project_apis)}"
  provider                   = "google-beta"
  service                    = "${var.gcp_project_apis[count.index]}"
  disable_dependent_services = false
  disable_on_destroy         = false
}

// VPC
resource "google_compute_network" "net" {
  provider                = "google-beta"
  name                    = "${var.env}"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "subnet" {
  provider           = "google-beta"
  name               = "${var.region}"
  ip_cidr_range      = "10.128.0.0/16"
  region             = "${var.region}"
  network            = "${google_compute_network.net.self_link}"
  secondary_ip_range = [
    {
      ip_cidr_range = "10.130.0.0/16"
      range_name    = "gke-pods"
    },
    {
      ip_cidr_range = "10.131.0.0/16"
      range_name    = "gke-services"
    }
  ]
}
resource "google_compute_firewall" "net-allow-privileged" {
  provider  = "google-beta"
  name      = "${google_compute_network.net.name}-allow-privileged"
  network   = "${google_compute_network.net.name}"
  direction = "INGRESS"
  disabled  = false
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = [
      "80",
      "443",
      "22"
    ]
  }

  source_ranges = "${var.ip_address_whitelist}"
}

// Cluster
resource "google_compute_address" "cluster_ip" {
  provider     = "google-beta"
  name         = "gke-${var.env}-lb"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  region       = "${var.region}"
}
resource "google_container_cluster" "cluster" {
  depends_on = [
    "google_project_service.apis"
  ]
  provider   = "google-beta"
  name       = "${var.env}"
  zone       = "${var.zone}"

  enable_binary_authorization = false
  enable_kubernetes_alpha     = false
  enable_tpu                  = false
  enable_legacy_abac          = false
  initial_node_count          = 1
  logging_service             = "logging.googleapis.com/kubernetes"
  min_master_version          = "${var.gke_version}"
  monitoring_service          = "monitoring.googleapis.com/kubernetes"
  network                     = "${google_compute_network.net.self_link}"
  node_version                = "${var.gke_version}"
  remove_default_node_pool    = true
  subnetwork                  = "${google_compute_subnetwork.subnet.self_link}"

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = true
    }
    kubernetes_dashboard {
      disabled = true
    }
    network_policy_config {
      disabled = true
    }
  }

  cluster_autoscaling {
    enabled = false
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  maintenance_policy {
    "daily_maintenance_window" {
      start_time = "04:00"
    }
  }

  master_auth {
    username = "${var.gke_master_username}"
    password = "${var.gke_master_password}"
    client_certificate_config {
      issue_client_certificate = true
    }
  }

  network_policy {
    enabled = false
  }

  pod_security_policy_config {
    enabled = false
  }
}
resource "google_container_node_pool" "main" {
  provider           = "google-beta"
  name               = "main"
  zone               = "${google_container_cluster.cluster.zone}"
  cluster            = "${google_container_cluster.cluster.name}"
  initial_node_count = 1

  autoscaling {
    max_node_count = 3
    min_node_count = 1
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    disk_size_gb = 50
    disk_type    = "pd-standard"
    machine_type = "n1-standard-2"
    preemptible  = true
    tags         = [
      "gke"
    ]
  }
}

// DNS
resource "cloudflare_record" "cluster" {
  domain  = "kfirs.com"
  name    = "cluster.${var.env}.kfirs.com"
  type    = "A"
  value   = "${google_compute_address.cluster_ip.address}"
  ttl     = 1
  proxied = false
}
resource "cloudflare_record" "alerts" {
  domain  = "kfirs.com"
  name    = "alerts.prometheus.${var.env}.kfirs.com"
  type    = "CNAME"
  value   = "${cloudflare_record.cluster.name}"
  ttl     = 1
  proxied = false
}
resource "cloudflare_record" "grafana" {
  domain  = "kfirs.com"
  name    = "grafana.${var.env}.kfirs.com"
  type    = "CNAME"
  value   = "${cloudflare_record.cluster.name}"
  ttl     = 1
  proxied = false
}
resource "cloudflare_record" "prometheus" {
  domain  = "kfirs.com"
  name    = "prometheus.${var.env}.kfirs.com"
  type    = "CNAME"
  value   = "${cloudflare_record.cluster.name}"
  ttl     = 1
  proxied = false
}
resource "cloudflare_record" "traefik" {
  domain  = "kfirs.com"
  name    = "traefik.${var.env}.kfirs.com"
  type    = "CNAME"
  value   = "${cloudflare_record.cluster.name}"
  ttl     = 1
  proxied = false
}

// Template for output file
data "template_file" "dotenv" {
  template = "${file("${path.module}/dotenv.tpl")}"
  vars {
    gke_admin                 = "${var.gke_admin}"
    alertmanager_slack_url    = "${var.alertmanager_slack_url}"
    cloudflare_email          = "${var.cloudflare_email}"
    cloudflare_token          = "${var.cloudflare_token}"
    cluster_ip_address        = "${google_compute_address.cluster_ip.address}"
    env                       = "${var.env}"
    grafana_admin_password    = "${var.grafana_admin_password}"
    grafana_db_root_password  = "${var.grafana_db_root_password}"
    grafana_db_user_password  = "${var.grafana_db_user_password}"
    ip_address_whitelist      = "${join(",",var.ip_address_whitelist)}"
    kubewatch_slack_token     = "${var.kubewatch_slack_token}"
    letsencrypt_account_email = "${var.letsencrypt_account_email}"
    letsencrypt_url           = "${var.letsencrypt_url}"
  }
}
resource "local_file" "dotenv" {
  content  = "${data.template_file.dotenv.rendered}"
  filename = "${path.module}/.env"
}
