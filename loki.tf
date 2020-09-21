locals {

  log_driver = "loki"
  log_opts = {
    "loki-url" = "http://localhost:3100/loki/api/v1/push"
  }

  loki_config = {
    auth_enabled = false

    server = {
      http_listen_port = 3100
      log_level        = "info"
    }

    ingester = {
      lifecycler = {
        address = "127.0.0.1"
        ring = {
          kvstore = {
            store : "inmemory"
          }
          replication_factor : 1
        }
        final_sleep = "0s"

      }
      chunk_idle_period   = "5m"
      chunk_retain_period = "30s"
    }

    schema_config = {
      configs = [
        {
          from         = "2018-04-15"
          store        = "boltdb"
          object_store = "filesystem"
          schema       = "v9"
          index = {
            prefix = "index_"
            period = "168h"
          }

        }
      ]
    }

    storage_config = {
      boltdb = {
        # TODO: find a better dir!
        directory = "/data/index"
      }
      filesystem = {
        # TODO: find a better dir!
        directory = "/data/chunks"
      }
    }

    limits_config = {
      enforce_metric_name : false
      reject_old_samples : true
      reject_old_samples_max_age : "168h"
    }

    chunk_store_config = {
      max_look_back_period : 0
    }

    table_manager = {
      chunk_tables_provisioning = {
        inactive_read_throughput     = 0
        inactive_write_throughput    = 0
        provisioned_read_throughput  = 0
        provisioned_write_throughput = 0

      }
      index_tables_provisioning = {
        inactive_read_throughput     = 0
        inactive_write_throughput    = 0
        provisioned_read_throughput  = 0
        provisioned_write_throughput = 0

      }
      retention_deletes_enabled = false
      retention_period          = 0
    }
  }
}


resource "linuxbox_directory" "loki_dir" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address
  path         = "${var.linuxbox_directory}/loki"
}

resource "linuxbox_directory" "loki_data_dir" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address
  path         = "${linuxbox_directory.loki_dir.path}/data"

  owner = 10001
  group = 10001
}


resource "linuxbox_text_file" "loki_local_config" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.loki_dir.path}/local-config.yaml"
  content = yamlencode(local.loki_config)
}

resource "linuxbox_docker_container" "loki" {

  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  restart = "always"

  image_id = var.loki_image

  args = [
    "-config.file=/etc/loki/local-config.yaml"
  ]

  ports = [
    "127.0.0.1:3100:3100"
  ]

  labels = {
    "prometheus-scrape.enabled" = "true"
    "prometheus-scrape.port"    = "3100"
    "config-hash"               = sha256(linuxbox_text_file.loki_local_config.content)

  }

  name = "linuxbox-loki"

  network = var.docker_network

  volumes = [
    "${linuxbox_text_file.loki_local_config.path}:/etc/loki/local-config.yaml:ro",
    "${linuxbox_directory.loki_data_dir.path}:/data",
  ]

  log_driver = local.log_driver
  log_opts   = local.log_opts

  memory = var.loki_memory
}

resource "linuxbox_run_setup" "install_loki_logging_driver" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  setup = [
    "docker plugin install '${var.loki_docker_driver_image}' --alias loki --grant-all-permissions",
  ]
}
