# web: ip1 por DHCP (NAT), ip2 estática en la red de datos
output "web" {
  value = {
    nombre = libvirt_domain.web.name
    ip1    = try(libvirt_domain.web.network_interface[0].addresses[0], "No disponible")
    ip2    = "10.0.0.10" # estática: está en cloud-init/network-config-web.yaml
  }
}

# bd: ip1 por DHCP (NAT), ip2 estática en la red de datos
output "bd" {
  value = {
    nombre = libvirt_domain.bd.name
    ip1    = try(libvirt_domain.bd.network_interface[0].addresses[0], "No disponible")
    ip2    = "10.0.0.20" # estática: está en cloud-init/network-config-bd.yaml
  }
}
