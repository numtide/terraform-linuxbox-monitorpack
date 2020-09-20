locals {
  prometheus_config = {
    global = {
      evaluation_interval = "5s"
      scrape_interval     = "30s"
      scrape_timeout      = "10s"
    }

    scrape_configs = [
      {
        job_name        = "docker_service_discovery"
        file_sd_configs = [{ files = ["/prometheus-docker-sd/docker-targets.json"] }]
      },
    ]

    alerting = {
      alertmanagers = [
        {
          static_configs = [
            {
              targets = ["alertmanager:9093"]
            },
          ]
        },
      ]
    }

    rule_files = ["alerting.rules.yml"]

  }

  prometheus_alerting_rules = {
    groups = [
      {
        name = "service is down"
        rules = [
          {
            alert = "Service is down"
            expr  = "critic_target_is_healthy == 0"
            for   = "1m"
            labels = {
              type = "event"
            }
            annotations = {
              title = "Service [{{ $labels.name }}] is not healthy on ${local.chatbox_full_hostname}"
              text  = ""
            }
          },
        ]
      }
    ]

  }

  prometheus_path_prefix = "${var.devops_path_prefix}/prometheus"

}


resource "linuxbox_directory" "prometheus" {
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  path = "${var.linuxbox_directory}/prometheus"
}

resource "linuxbox_directory" "prometheus_data" {
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  path  = "${linuxbox_directory.prometheus.path}/data"
  owner = 65534
  group = 65534
}

resource "linuxbox_directory" "prometheus_sd" {
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  path = "${linuxbox_directory.prometheus.path}/sd"
}

resource "linuxbox_text_file" "prometheus_config" {
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.prometheus.path}/prometheus.yml"
  content = yamlencode(local.prometheus_config)
}

resource "linuxbox_text_file" "prometheus_alerting_rules" {
  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.prometheus.path}/alerting.rules.yml"
  content = yamlencode(local.prometheus_alerting_rules)
}

resource "linuxbox_docker_container" "prometheus" {
  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  ssh_key      = var.ssh_key
  ssh_username = var.ssh_username
  host_address = var.ssh_host_address

  image_id = var.prometheus_image

  labels = merge({
    "traefik.enable"                                            = "true"
    "traefik.http.services.prometheus.loadbalancer.server.port" = "9090"
    "traefik.http.routers.prometheus.rule"                      = "Host(`${local.chatbox_full_hostname}`) && PathPrefix(`${local.prometheus_path_prefix}`)"
    "traefik.http.routers.prometheus.tls.certresolver"          = module.traefik.certificate_resolver_name

    "prometheus-scrape.enabled"      = "true"
    "prometheus-scrape.metrics_path" = "${local.prometheus_path_prefix}/metrics"
    // will force re-load container when the config changes.
    "config-hash" = sha256(linuxbox_text_file.prometheus_config.content)
    },
    var.container_labels,
  )

  name = "linuxbox-prometheus"

  restart = "always"

  network = var.docker_network

  env = {
    GITHUB_OAUTH2_CLIENT_ID     = local.github_oauth2_client_id
    GITHUB_OAUTH2_CLIENT_SECRET = local.github_oauth2_client_secret
    JWT_SIGN_SECRET             = local.jwt_sign_secret
  }
  volumes = [
    "${linuxbox_directory.prometheus_data.path}:/data",
    "${linuxbox_text_file.prometheus_config.path}:/run/secrets/prometheus.yml:ro",
    "${linuxbox_text_file.prometheus_alerting_rules.path}:/run/secrets/alerting.rules.yml:ro",

    "${linuxbox_directory.prometheus.path}:/prometheus-docker-sd",
  ]

  args = [
    "--config.file=/run/secrets/prometheus.yml",
    "--web.enable-admin-api",
    "--web.external-url=https://${local.chatbox_full_hostname}${local.prometheus_path_prefix}",
    "--storage.tsdb.path=/data",
    "--storage.tsdb.retention.time=30d",
  ]

  log_driver = local.log_driver
  log_opts   = local.log_opts

  memory = var.prometheus_memory
}
