
# TODO - monitor containers: https://github.com/google/cadvisor/pull/2268/files

resource "linuxbox_docker_container" "cadvisor" {

  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  image_id = var.cadvisor_image
  name     = "linuxbox-cadvisor"
  volumes = [
    "/:/rootfs:ro",
    "/var/run:/var/run:ro",
    "/sys:/sys:ro",
    "/var/lib/docker/:/var/lib/docker:ro",
    "/dev/disk/:/dev/disk:ro",

  ]

  privileged = true

  // TODO: add `devices` to linuxbox container!

  labels = merge(
    {
      "prometheus-scrape.enabled" = "true"
      "prometheus-scrape.port"    = "8080"
    },
    var.container_labels,
  )


  restart = "always"

  network = var.docker_network

  args = [
    "--docker_only",
    "--disable_metrics", "tcp,udp",
    "--housekeeping_interval=55s"
  ]

  memory = var.cadvisor_memory

  log_driver = local.log_driver
  log_opts   = local.log_opts

}
