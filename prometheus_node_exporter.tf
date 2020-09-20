resource "linuxbox_docker_container" "node_exporter" {
  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  image_id = var.prometheus_node_exporter_image

  name = "linuxbox-prometheus-node-exporter"

  restart = "always"

  network = var.docker_network

  volumes = [
    "/:/host:ro",
  ]

  labels = merge(
    {
      "prometheus-scrape.enabled" = "true"
      "prometheus-scrape.port"    = "9100"
    },
    local.container_labels,
  )

  // TODO: add support for pid to linuxbox

  args = [
    "--path.rootfs=/host",
  ]

  log_driver = local.log_driver
  log_opts   = local.log_opts

}
