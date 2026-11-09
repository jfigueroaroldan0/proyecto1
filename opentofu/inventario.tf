# Genera el inventario de Ansible (../ansible/hosts) a partir de las IP del escenario
resource "local_file" "inventario" {
  filename        = "${path.module}/../ansible/hosts"
  file_permission = "0644"
  content = templatefile("${path.module}/inventario.tftpl", {
    webs           = { for n, d in libvirt_domain.web : n => try(d.network_interface[0].addresses[0], "") }
    ip_balanceador = try(libvirt_domain.balanceador.network_interface[0].addresses[0], "")
    ip_bd          = try(libvirt_domain.bd.network_interface[0].addresses[0], "")
  })
}
