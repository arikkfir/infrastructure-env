ADMIN_USR=${gke_admin}
ALERTMGR_SLACK_URL=${alertmanager_slack_url}
CLOUDFLARE_EMAIL=${cloudflare_email}
CLOUDFLARE_TOKEN=${cloudflare_token}
CLOUDFLARE_TOKEN_BASE64=${base64encode(cloudflare_token)}
GKE_CLUSTER_IP_ADDR=${cluster_ip_address}
GKE_CLUSTER_NAME=${env}
GRAFANA_ADMIN_PASSWORD=${grafana_admin_password}
GRAFANA_ADMIN_PASSWORD_BASE64=${base64encode(grafana_admin_password)}
GRAFANA_DB_ROOT_PASSWORD=${grafana_db_root_password}
GRAFANA_DB_ROOT_PASSWORD_BASE64=${base64encode(grafana_db_root_password)}
GRAFANA_DB_USER_PASSWORD=${grafana_db_user_password}
GRAFANA_DB_USER_PASSWORD_BASE64=${base64encode(grafana_db_user_password)}
KUBEWATCH_SLACK_TOKEN=${kubewatch_slack_token}
LETSENCRYPT_ACCOUNT_EMAIL=${letsencrypt_account_email}
LETSENCRYPT_URL=${letsencrypt_url}
WHITELISTED_CIDR=${ip_address_whitelist}
