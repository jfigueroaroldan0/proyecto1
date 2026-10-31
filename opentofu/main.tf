##############################################
# web — Debian 13 (Apache + PHP)
##############################################

# Clon ligero sobre la imagen base Debian
resource "libvirt_volume" "web-disk" {
  name             = "web-linked.qcow2"
  pool             = var.libvirt_pool_name
  base_volume_name = var.base_image_debian
  base_volume_pool = var.libvirt_pool_name
  format           = "qcow2"
}

# ISO cloud-init con la configuración inicial de web
resource "libvirt_cloudinit_disk" "web-cloudinit" {
  name           = "web-cloudinit.iso"
  pool           = var.libvirt_pool_name
  user_data      = file("${path.module}/cloud-init/user-data-web.yaml")
  network_config = file("${path.module}/cloud-init/network-config-web.yaml")
}

resource "libvirt_domain" "web" {
  name   = "web"
  memory = var.memoria_web
  vcpu   = 1

  # Red 1 (ens3): NAT con DHCP
  network_interface {
    network_id     = libvirt_network.p1-red-nat.id
    wait_for_lease = true
  }

  # Red 2 (ens4): red de datos (IP estática 10.0.0.10)
  network_interface {
    network_id = libvirt_network.p1-red-datos.id
  }

  disk { volume_id = libvirt_volume.web-disk.id }
  cloudinit = libvirt_cloudinit_disk.web-cloudinit.id

  # Consola serie: las imágenes cloud la esperan (sin ella, algunas, como
  # Ubuntu, no terminan de arrancar) y permite entrar con "virsh console"
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
