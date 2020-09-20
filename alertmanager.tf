
locals {
  alertmanager_config = {
    global = {
      slack_api_url = local.netice9_alerts_slack_webhook
    }
    route = {
      receiver        = "slack_event"
      group_wait      = "10s"
      group_interval  = "5m"
      repeat_interval = "12h"
      group_by        = ["name", "alertname"]
      routes = [
        {
          receiver        = "slack_event"
          repeat_interval = "1h"
          match = {
            type = "event"
          }
        },
      ]

    }

    receivers = [
      {
        name = "slack_event"
        slack_configs = [
          {
            channel       = "#alerts"
            title         = "{{ range .Alerts }}{{ .Annotations.title }}\n{{ end }}"
            title_link    = ""
            text          = "{{ range .Alerts }}{{ .Annotations.text }}\n{{ end }}"
            send_resolved = true
          },
        ]
      }
    ]

  }
}

locals {
  alert_manager_count = var.slack_alertmanager_webhook != null ? 1 : 0
}

resource "linuxbox_directory" "alertmanager" {
  count        = local.alert_manager_count
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  path = "${var.linuxbox_directory}/alertmanager"
}

resource "linuxbox_text_file" "alertmanager_config" {
  count        = local.alert_manager_count
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.alertmanager.path}/alertmanager.yml"
  content = yamlencode(local.alertmanager_config)
}

resource "linuxbox_docker_container" "alertmanager" {
  count = local.alert_manager_count
  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  image_id = "prom/alertmanager:v0.21.0"

  labels = merge({
    "prometheus-scrape.enabled" = "true"
    "prometheus-scrape.port"    = "9093"
    },
    var.container_labels,
  )

  name = "linxubox-alertmanager"

  restart = "always"

  network = var.docker_network

  log_driver = local.log_driver
  log_opts   = local.log_opts


  volumes = [
    "${linuxbox_text_file.alertmanager_config.path}:/etc/alertmanager/alertmanager.yml:ro",
  ]
}

