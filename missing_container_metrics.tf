resource "linuxbox_docker_container" "missing_container_metrics" {

  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  restart = "always"

  image_id = var.missing_container_metrics_image

  name = "linuxbox-missing-container-metrics"

  network = var.docker_network

  volumes = ["/var/run/docker.sock:/var/run/docker.sock"]

  labels = merge(
    {
      "prometheus-scrape.enabled" = "true"
      "prometheus-scrape.port"    = "3001"
    },
    var.container_labels,
  )

  log_driver = local.log_driver
  log_opts   = local.log_opts


  memory = var.missing_container_metrics_memory
}
