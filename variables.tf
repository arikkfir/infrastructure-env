variable "name" {
  description = "Environment name."
}
variable "gcp_project_id" {
  description = "GCP project ID."
}
variable "gke_master_password" {
  description = "GKE master password."
}
variable "gke_master_username" {
  description = "GKE master username."
}
variable "gke_master_version" {
  description = "GKE Kubernetes version for API nodes."
}
variable "gke_node_version" {
  description = "GKE Kubernetes version for worker nodes."
}
variable "whitelisted_cidrs" {
  description = "Whitelisted CIDR ranges allowed to access the services on the cluster."
  type = "list"
}
