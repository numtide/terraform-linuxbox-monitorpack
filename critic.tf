resource "linuxbox_docker_container" "critic" {

  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  restart = "always"

  image_id = var.critic_image

  env = { for k, v in var.critic_targets : "WATCH_${k}" => v }

  labels = merge({
    "prometheus-scrape.enabled" = "true"
    "prometheus-scrape.port"    = "3001"
    },
    var.container_labels,
  )
  
  name = "linuxbox-critic"

  network = var.docker_network

  log_driver = local.log_driver
  log_opts   = local.log_opts

}
