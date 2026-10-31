# Red NAT con DHCP: acceso desde el anfitrión y salida a Internet
resource "libvirt_network" "p1-red-nat" {
  name      = "p1-red-nat"
  mode      = "nat"
  addresses = ["192.168.210.0/24"]
  bridge    = "br-p1-nat"
  dhcp { enabled = true }
  dns { enabled = true }
  autostart = true
}

# Red muy aislada (mode=none): solo la usan web y bd para comunicarse.
# Sin DHCP y el anfitrión no tiene IP en ella.
resource "libvirt_network" "p1-red-datos" {
  name      = "p1-red-datos"
  mode      = "none"
  bridge    = "br-p1-datos"
  autostart = true
}
