# Genera el inventario de Ansible (../ansible/hosts) a partir de las IP del escenario
resource "local_file" "inventario" {
  filename        = "${path.module}/../ansible/hosts"
  file_permission = "0644"
  content = templatefile("${path.module}/inventario.tftpl", {
    ip_web = try(libvirt_domain.web.network_interface[0].addresses[0], "")
    ip_bd  = try(libvirt_domain.bd.network_interface[0].addresses[0], "")
  })
}
