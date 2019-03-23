resource "google_compute_network" "main" {
  provider                = "google-beta"
  project                 = "${var.gcp_project_id}"
  name                    = "${var.name}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  provider           = "google-beta"
  project            = "${var.gcp_project_id}"
  name               = "europe-west1"
  ip_cidr_range      = "10.128.0.0/16"
  region             = "europe-west1"
  network            = "${google_compute_network.main.self_link}"
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

resource "google_compute_address" "main" {
  provider     = "google-beta"
  project      = "${var.gcp_project_id}"
  name         = "gke-${var.name}-lb"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  region       = "europe-west1"
}

resource "google_container_cluster" "main" {
  provider                    = "google-beta"
  project                     = "${var.gcp_project_id}"
  name                        = "${var.name}"
  zone                        = "europe-west1-b"
  enable_binary_authorization = false
  enable_kubernetes_alpha     = false
  enable_tpu                  = false
  enable_legacy_abac          = false
  initial_node_count          = 1
  logging_service             = "logging.googleapis.com/kubernetes"
  min_master_version          = "${var.gke_master_version}"
  monitoring_service          = "monitoring.googleapis.com/kubernetes"
  network                     = "${google_compute_network.main.self_link}"
  remove_default_node_pool    = true
  subnetwork                  = "${google_compute_subnetwork.main.self_link}"
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
      issue_client_certificate = false
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
  project            = "${var.gcp_project_id}"
  name               = "main"
  zone               = "${google_container_cluster.main.zone}"
  cluster            = "${google_container_cluster.main.name}"
  version            = "${var.gke_node_version}"
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
    tags         = ["gke"]
    metadata {
      "disable-legacy-endpoints" = "true"
    }
  }
}
resource "cloudflare_record" "cluster" {
  domain  = "kfirs.com"
  name    = "cluster.${var.name}.kfirs.com"
  type    = "A"
  value   = "${google_compute_address.main.address}"
  ttl     = 1
  proxied = false
}
resource "cloudflare_record" "alertmanager" {
  domain  = "kfirs.com"
  name    = "alertmanager.${var.name}.kfirs.com"
  type    = "CNAME"
  value   = "${cloudflare_record.cluster.name}"
  ttl     = 1
  proxied = false
}
resource "cloudflare_record" "prometheus" {
  domain  = "kfirs.com"
  name    = "prometheus.${var.name}.kfirs.com"
  type    = "CNAME"
  value   = "${cloudflare_record.cluster.name}"
  ttl     = 1
  proxied = false
}
resource "cloudflare_record" "traefik" {
  domain  = "kfirs.com"
  name    = "traefik.${var.name}.kfirs.com"
  type    = "CNAME"
  value   = "${cloudflare_record.cluster.name}"
  ttl     = 1
  proxied = false
}
