# Pool de almacenamiento donde se crean los volúmenes (disco y cloud-init)
variable "libvirt_pool_name" {
  type        = string
  description = "Nombre del pool de almacenamiento libvirt."
  default     = "default"
}

# Imagen base Debian 13 para web
variable "base_image_debian" {
  type        = string
  description = "Nombre de la imagen base Debian en el pool."
  default     = "debian-13-generic-amd64.qcow2"
}

# Imagen base Ubuntu 26.04 para bd
variable "base_image_ubuntu" {
  type        = string
  description = "Nombre de la imagen base Ubuntu en el pool."
  default     = "resolute-server-cloudimg-amd64.img"
}

# Memoria de las máquinas (MB)
variable "memoria_web" {
  type        = number
  description = "Memoria RAM (MB) del servidor web."
  default     = 1024
}

variable "memoria_bd" {
  type        = number
  description = "Memoria RAM (MB) del servidor de base de datos."
  default     = 1024
}
