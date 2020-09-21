locals {
  grafana_path_prefix = "${var.devops_path_prefix}/grafana"

  grafana_ini = {
    server = {
      root_url            = "https://${var.host_name}${local.grafana_path_prefix}"
      serve_from_sub_path = "true"
    }

    users = {
      viewers_can_edit = true // but not save; copy+paste them into Terraform
    }

    auth = {
      disable_login_form = false
    }

    "auth.anonymous" = {
      enabled  = true
      org_role = "Viewer"
      # org_role = "Admin"
    }

    "security" = {
      admin_user     = "draganm"
      admin_password = "draganm"
    }
  }

  grafana_ini_content = <<-EOT
    %{~for k, v in local.grafana_ini}
    [${k}]
    %{for sk, sv in v~}
    ${sk} = ${sv}
    %{endfor~}
    %{endfor~}
    EOT


  grafana_datasources = {
    apiVersion = 1
    datasources = [
      {
        name      = "prometheus"
        type      = "prometheus"
        url       = "http://${linuxbox_docker_container.prometheus.name}:9090${local.prometheus_path_prefix}"
        access    = "proxy"
        isDefault = "true"
      },
      {
        name = "loki"
        type = "loki"
        url  = "http://${linuxbox_docker_container.loki.name}:3100"
      }
    ]
  }

  grafana_dashboard_providers = {
    apiVersion = 1
    providers = [
      {
        name     = "default"
        orgId    = 1
        folder   = ""
        type     = "file"
        editable = false
        options = {
          path = "/var/lib/grafana/dashboards"
        }
        disableDeletion = false
      }
    ]
  }

}

resource "linuxbox_directory" "grafana_data_dir" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path  = "${linuxbox_directory.grafana_dir.path}/data"
  owner = 472
  group = 472
}

resource "linuxbox_directory" "grafana_dir" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path  = "${var.linuxbox_directory}/grafana"
  owner = 0
  group = 0
}


resource "linuxbox_text_file" "grafana_ini" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.grafana_dir.path}/grafana.ini"
  content = local.grafana_ini_content
}


resource "linuxbox_text_file" "grafana_datasources_yaml" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.grafana_dir.path}/datasources.yaml"
  content = yamlencode(local.grafana_datasources)
}

resource "linuxbox_text_file" "grafana_dashboard_providers_yaml" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.grafana_dir.path}/dashboard-providers.yaml"
  content = yamlencode(local.grafana_dashboard_providers)
}


resource "linuxbox_docker_run" "grafana_install_piechart_plugin" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  image_id = var.grafana_image

  clear_entry_point = true

  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  volumes = [
    "${linuxbox_directory.grafana_data_dir.path}:/var/lib/grafana",
    "${linuxbox_text_file.grafana_ini.path}:/etc/grafana/grafana.ini:ro",
    "${linuxbox_text_file.grafana_datasources_yaml.path}:/etc/grafana/provisioning/datasources/datasources.yaml:ro",
    "${linuxbox_text_file.grafana_dashboard_providers_yaml.path}:/etc/grafana/provisioning/dashboards/dashboards-providers.yaml:ro",
  ]

  args = [
    "grafana-cli", "plugins", "install", "grafana-piechart-panel"
  ]

}

resource "linuxbox_docker_run" "grafana_install_statusmap_panel_plugin" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  image_id = var.grafana_image

  clear_entry_point = true

  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
  ]

  volumes = [
    "${linuxbox_directory.grafana_data_dir.path}:/var/lib/grafana",
    "${linuxbox_text_file.grafana_ini.path}:/etc/grafana/grafana.ini:ro",
    "${linuxbox_text_file.grafana_datasources_yaml.path}:/etc/grafana/provisioning/datasources/datasources.yaml:ro",
    "${linuxbox_text_file.grafana_dashboard_providers_yaml.path}:/etc/grafana/provisioning/dashboards/dashboards-providers.yaml:ro",
  ]

  args = [
    "grafana-cli", "plugins", "install", "flant-statusmap-panel"
  ]

}

resource "linuxbox_docker_container" "grafana" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  image_id = var.grafana_image

  depends_on = [
    linuxbox_run_setup.install_loki_logging_driver,
    linuxbox_docker_run.grafana_install_piechart_plugin,
    linuxbox_docker_run.grafana_install_statusmap_panel_plugin,
  ]

  labels = merge({
    "traefik.enable"                                         = "true"
    "traefik.http.services.grafana.loadbalancer.server.port" = "3000"
    "traefik.http.routers.grafana.rule"                      = "Host(`${var.host_name}`) && PathPrefix(`${local.grafana_path_prefix}`)"
    "traefik.http.routers.grafana.tls.certresolver"          = var.traefik_certificate_resolver_name
    "prometheus-scrape.enabled"                              = "true"
    "prometheus-scrape.port"                                 = "3000"
    },
    var.container_labels,
  )

  name = "linuxbox-grafana"

  restart = "unless-stopped"

  network = var.docker_network

  volumes = [
    "${linuxbox_directory.grafana_data_dir.path}:/var/lib/grafana",
    "${linuxbox_text_file.grafana_ini.path}:/etc/grafana/grafana.ini:ro",
    "${linuxbox_text_file.grafana_datasources_yaml.path}:/etc/grafana/provisioning/datasources/datasources.yaml:ro",
    "${linuxbox_text_file.grafana_dashboard_providers_yaml.path}:/etc/grafana/provisioning/dashboards/dashboards-providers.yaml:ro",
  ]

  env = {
    GF_PATHS_CONFIG       = "/etc/grafana/grafana.ini"
    GF_PATHS_DATA         = "/var/lib/grafana"
    GF_PATHS_HOME         = "/usr/share/grafana"
    GF_PATHS_LOGS         = "/var/log/grafana"
    GF_PATHS_PLUGINS      = "/var/lib/grafana/plugins"
    GF_PATHS_PROVISIONING = "/etc/grafana/provisioning"
    PATH                  = "/usr/share/grafana/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  }

  log_driver = local.log_driver
  log_opts   = local.log_opts

  memory = var.grafana_memory
}


resource "linuxbox_directory" "grafana_dashboards_dir" {
  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path  = "${linuxbox_directory.grafana_data_dir.path}/dashboards"
  owner = 472
  group = 472
}

resource "linuxbox_text_file" "grafana_dashboards" {
  for_each = fileset(path.module, "grafana/*.json")

  ssh_key      = var.ssh_key
  ssh_user     = var.ssh_username
  host_address = var.ssh_host_address

  path    = "${linuxbox_directory.grafana_dashboards_dir.path}/${basename(each.key)}"
  content = file("${path.module}/${each.key}")

  owner = 472
  group = 472
}
