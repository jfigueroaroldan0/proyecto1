##############################################
# web1 y web2 — Debian 13 (Apache + PHP)
##############################################

# Mapa de los servidores web: nombre -> IP en la red de datos.
# Añadir o quitar un backend es tan simple como editar este mapa.
locals {
  webs = {
    web1 = "10.0.0.11"
    web2 = "10.0.0.12"
  }
}

# Clon ligero sobre la imagen base Debian (uno por web)
resource "libvirt_volume" "web-disk" {
  for_each         = local.webs
  name             = "${each.key}-linked.qcow2"
  pool             = var.libvirt_pool_name
  base_volume_name = var.base_image_debian
  base_volume_pool = var.libvirt_pool_name
  format           = "qcow2"
}

# ISO cloud-init de cada web (un fichero YAML por máquina: user-data-webN.yaml
# y network-config-webN.yaml)
resource "libvirt_cloudinit_disk" "web-cloudinit" {
  for_each       = local.webs
  name           = "${each.key}-cloudinit.iso"
  pool           = var.libvirt_pool_name
  user_data      = file("${path.module}/cloud-init/user-data-${each.key}.yaml")
  network_config = file("${path.module}/cloud-init/network-config-${each.key}.yaml")
}

resource "libvirt_domain" "web" {
  for_each = local.webs
  name     = each.key
  memory   = var.memoria_web
  vcpu     = 1

  # Red 1 (ens3): NAT con DHCP
  network_interface {
    network_id     = libvirt_network.p1-red-nat.id
    wait_for_lease = true
  }

  # Red 2 (ens4): red de datos (IP estática 10.0.0.1x)
  network_interface {
    network_id = libvirt_network.p1-red-datos.id
  }

  disk { volume_id = libvirt_volume.web-disk[each.key].id }
  cloudinit = libvirt_cloudinit_disk.web-cloudinit[each.key].id

  # Consola serie: las imágenes cloud la esperan (sin ella, algunas, como
  # Ubuntu, no terminan de arrancar) y permite entrar con "virsh console"
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

##############################################
# balanceador — Debian 13 (HAProxy)
##############################################

# Clon ligero sobre la imagen base Debian
resource "libvirt_volume" "balanceador-disk" {
  name             = "balanceador-linked.qcow2"
  pool             = var.libvirt_pool_name
  base_volume_name = var.base_image_debian
  base_volume_pool = var.libvirt_pool_name
  format           = "qcow2"
}

# ISO cloud-init con la configuración inicial del balanceador
resource "libvirt_cloudinit_disk" "balanceador-cloudinit" {
  name           = "balanceador-cloudinit.iso"
  pool           = var.libvirt_pool_name
  user_data      = file("${path.module}/cloud-init/user-data-balanceador.yaml")
  network_config = file("${path.module}/cloud-init/network-config-balanceador.yaml")
}

resource "libvirt_domain" "balanceador" {
  name   = "balanceador"
  memory = var.memoria_balanceador
  vcpu   = 1

  # Red 1 (ens3): NAT con DHCP (punto de entrada desde el anfitrión)
  network_interface {
    network_id     = libvirt_network.p1-red-nat.id
    wait_for_lease = true
  }

  # Red 2 (ens4): red de datos (IP estática 10.0.0.30, habla con los web)
  network_interface {
    network_id = libvirt_network.p1-red-datos.id
  }

  disk { volume_id = libvirt_volume.balanceador-disk.id }
  cloudinit = libvirt_cloudinit_disk.balanceador-cloudinit.id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

##############################################
# bd — Ubuntu 26.04 (MariaDB)
##############################################

# Clon ligero sobre la imagen base Ubuntu
resource "libvirt_volume" "bd-disk" {
  name             = "bd-linked.qcow2"
  pool             = var.libvirt_pool_name
  base_volume_name = var.base_image_ubuntu
  base_volume_pool = var.libvirt_pool_name
  format           = "qcow2"
}

# ISO cloud-init con la configuración inicial de bd
resource "libvirt_cloudinit_disk" "bd-cloudinit" {
  name           = "bd-cloudinit.iso"
  pool           = var.libvirt_pool_name
  user_data      = file("${path.module}/cloud-init/user-data-bd.yaml")
  network_config = file("${path.module}/cloud-init/network-config-bd.yaml")
}

resource "libvirt_domain" "bd" {
  name   = "bd"
  memory = var.memoria_bd
  vcpu   = 1

  # Red 1 (ens3): NAT con DHCP
  network_interface {
    network_id     = libvirt_network.p1-red-nat.id
    wait_for_lease = true
  }

  # Red 2 (ens4): red de datos (IP estática 10.0.0.20)
  network_interface {
    network_id = libvirt_network.p1-red-datos.id
  }

  disk { volume_id = libvirt_volume.bd-disk.id }
  cloudinit = libvirt_cloudinit_disk.bd-cloudinit.id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}
