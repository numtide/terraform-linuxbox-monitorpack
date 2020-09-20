# This is a node project, probably worth investigating writing in go
# https://github.com/stuckyhm/prometheus-docker-sd
resource "linuxbox_docker_container" "prometheus-docker-sd" {
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  image_id = var.prometheus_docker_sd_image

  depends_on = [
    linuxbox_run_setup.install_docker,
  ]


  name = "linuxbox-prometheus-docker-sd"

  restart = "always"

  volumes = [
    "/var/run/docker.sock:/var/run/docker.sock",
    "${linuxbox_directory.prometheus.path}:/prometheus-docker-sd",
  ]

  log_driver = local.log_driver
  log_opts   = local.log_opts

}
