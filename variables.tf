variable "ssh_host_address" {
  type        = string
  description = "Hostname (or IP address of a host) with a running Docker instance where the traefik container is going to be installed."
}

variable "ssh_username" {
  type        = string
  description = "Username used to log in to the ssh host and run Docker commands, defaults to root."
  default     = "root"
}

variable "ssh_key" {
  type        = string
  description = "Private key used to authenticate SSH connection."
}

variable "docker_network" {
  type        = string
  description = "Docker network to attach the container to."
  default     = "bridge"
}

variable "container_name" {
  type        = string
  description = "Name of the created container"
  default     = "linuxbox-traefik"
}

variable "log_driver" {
  type        = string
  description = "Log driver to use for the Docker container."
  default     = null
}

variable "log_opts" {
  type        = map(string)
  description = "Log driver options for the Docker log driver."
  default     = null
}

variable "cadvisor_image" {
  type        = string
  description = "Docker image name/tag for the cadvisor container, you can use this value to install newer version of the image, or to run a custom image."
  default     = "gcr.io/cadvisor/cadvisor:v0.37.0"
}

variable "cadvisor_memory" {
  type        = number
  description = "Memory limit for the Docker container. Default is set to a sane value, but can be overriden."
  default     = 52 * 1024 * 1024
}

variable "container_labels" {
  type        = map(string)
  description = "Additional labels to add to all containers"
  value       = {}
}