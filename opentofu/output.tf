# web1 y web2: ip1 por DHCP (NAT), ip2 estática en la red de datos
output "web" {
  value = {
    for nombre, domain in libvirt_domain.web : nombre => {
      nombre = domain.name
      ip1    = try(domain.network_interface[0].addresses[0], "No disponible")
      ip2    = local.webs[nombre] # estática en la red de datos
    }
  }
}

# balanceador: ip1 por DHCP (NAT, punto de entrada), ip2 estática en datos
output "balanceador" {
  value = {
    nombre = libvirt_domain.balanceador.name
    ip1    = try(libvirt_domain.balanceador.network_interface[0].addresses[0], "No disponible")
    ip2    = "10.0.0.30" # estática: está en cloud-init/network-config-balanceador.yaml
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
