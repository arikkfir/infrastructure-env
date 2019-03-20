output "cluster_dns_name" {
  value = "${cloudflare_record.cluster.name}"
}

output "cluster_api_address" {
  value = "${google_container_cluster.main.endpoint}"
}

output "cluster_ingress_address" {
  value = "${google_compute_address.main.address}"
}
