# Genera el inventario de Ansible (../ansible/hosts) a partir de las IP del escenario.
# Los backends y el almacén ya no tienen interfaz NAT: se usa su IP estática en la
# red de datos y se llega a ellos por SSH a través del balanceador (ProxyJump).
resource "local_file" "inventario" {
  filename        = "${path.module}/../ansible/hosts"
  file_permission = "0644"
  content = templatefile("${path.module}/inventario.tftpl", {
    webs           = local.webs # IP estática en la red de datos de cada web
    ip_balanceador = try(libvirt_domain.balanceador.network_interface[0].addresses[0], "")
    ip_almacen     = "10.0.0.40"
    ip_bd          = "10.0.0.20"
  })
}
