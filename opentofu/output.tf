# web1 y web2: solo IP estática en la red de datos (ya no tienen interfaz NAT)
output "web" {
  value = {
    for nombre, domain in libvirt_domain.web : nombre => {
      nombre = domain.name
      ip2    = local.webs[nombre] # estática en la red de datos (única interfaz)
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

# almacen: solo IP estática en datos (exporta el NFS; ya no tiene interfaz NAT)
output "almacen" {
  value = {
    nombre = libvirt_domain.almacen.name
    ip2    = "10.0.0.40" # estática: está en cloud-init/network-config-almacen.yaml
  }
}

# bd: solo IP estática en datos (MariaDB; ya no tiene interfaz NAT)
output "bd" {
  value = {
    nombre = libvirt_domain.bd.name
    ip2    = "10.0.0.20" # estática: está en cloud-init/network-config-bd.yaml
  }
}
