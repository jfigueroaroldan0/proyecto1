# Proyecto 1: Infraestructura como código — Modificaciones 1 y 2 (Balanceo HAProxy + Almacenamiento compartido NFS)

Escenario creado con **OpenTofu** (libvirt/KVM) y configurado con **Ansible** que pone en producción la aplicación [guestbook_php](https://github.com/josedom24/guestbook_php) (PHP + MariaDB).

**Modificación 1 (balanceo):** se añade un servidor web (de uno a **dos backends**, `web1` y `web2`) y una máquina `balanceador` con **HAProxy** que reparte el tráfico entre ellos en *round-robin*.

**Modificación 2 (almacenamiento compartido):** se añade una máquina `almacen` con un **servidor NFS** que exporta el **DocumentRoot** de la aplicación. Los dos backends ya no guardan una copia propia de la web: la **montan por NFS** desde `almacen`, así se despliega la aplicación una sola vez y ambos sirven exactamente el mismo contenido (una única fuente de verdad).

## Escenario

```
                        Anfitrión
                            │ 192.168.210.1
                    ┌───────┴────────┐
                    │  p1-red-nat    │  192.168.210.0/24 (NAT + DHCP)
                    └───────┬────────┘
                       ens3 │ DHCP
                   ┌────────┴────────┐
                   │   balanceador   │  HAProxy (entrada)
                   └────────┬────────┘ ens4 10.0.0.30
       ┌─────────────────┬──┴──────────────┬─────────────────┐  (red de datos)
  ens4 │ 10.0.0.11  ens4 │ 10.0.0.12  ens4 │ 10.0.0.20   ens4 │ 10.0.0.40
┌──────┴──────┐   ┌──────┴──────┐   ┌──────┴──────┐   ┌────────┴────────┐
│    web1     │   │    web2     │   │     bd      │   │     almacen     │
│ Apache+PHP  │   │ Apache+PHP  │   │   MariaDB   │   │ NFS (DocumentRoot)
└──────┬──────┘   └──────┬──────┘   └─────────────┘   └────────┬────────┘
       └── montan NFS ───┴───────────────────────────────────┘
   p1-red-datos (muy aislada) · 10.0.0.0/24 · sin DHCP · el anfitrión no tiene IP
```

(web1, web2, bd y almacen también tienen interfaz en la red NAT con DHCP, para instalar paquetes.)

| Máquina | Imagen | Red NAT (ens3) | Red de datos (ens4) | Grupo de Ansible |
|---|---|---|---|---|
| balanceador | Debian 13 | DHCP | 10.0.0.30 | `servidores_balanceador` |
| web1 | Debian 13 | DHCP | 10.0.0.11 | `servidores_web` |
| web2 | Debian 13 | DHCP | 10.0.0.12 | `servidores_web` |
| bd  | Ubuntu 26.04 | DHCP | 10.0.0.20 | `servidores_bd` |
| almacen | Debian 13 | DHCP | 10.0.0.40 | `servidores_almacen` |

El anfitrión solo habla con el **balanceador** (red NAT); HAProxy reparte hacia `web1` y `web2`, que sirven la aplicación montada por **NFS** desde `almacen`. Todo el tráfico de datos (balanceo, NFS y BD) va por la **red de datos**, aislada.

## Estructura del repositorio

```
opentofu/
├── provider.tf              providers libvirt (0.8.3) y local
├── variables.tf             pool, imágenes base y memoria de las máquinas
├── network.tf               red NAT con DHCP y red de datos muy aislada
├── main.tf                  web (for_each: web1/web2), balanceador, almacen y bd
├── output.tf                nombre e IP (NAT y datos) de cada máquina
├── inventario.tf            genera ../ansible/hosts a partir de inventario.tftpl
├── inventario.tftpl
└── cloud-init/              un YAML por máquina (user-data y network-config)
ansible/
├── ansible.cfg
├── site.yaml
├── group_vars/all           nombres, IP, backends, NFS, usuarios y contraseñas
└── roles/
    ├── commons/             actualiza el sistema, paquetes comunes, /etc/hosts
    ├── bd/                  MariaDB, base de datos, usuario (desde los dos web) y tablas
    ├── nfs/                 servidor NFS + despliegue único de la aplicación (files/app/)
    ├── web/                 Apache + PHP, virtual host y montaje NFS del DocumentRoot
    └── balanceador/         HAProxy (reparto round-robin entre web1 y web2)
```

## Requisitos

- KVM/libvirt, OpenTofu y Ansible (con las colecciones `community.mysql`, `community.general`
  y `ansible.posix`; el paquete `ansible` de Debian ya las trae).
- Las imágenes base en el pool `default` (las máquinas son clones ligeros de ellas):
  - `web1`, `web2`, `balanceador` y `almacen` → Debian 13: `debian-13-generic-amd64.qcow2`
  - `bd` → Ubuntu 26.04: `resolute-server-cloudimg-amd64.img`

  ```bash
  cd /var/lib/libvirt/images
  sudo wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
  sudo wget https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img
  sudo qemu-img resize debian-13-generic-amd64.qcow2 10G
  sudo qemu-img resize resolute-server-cloudimg-amd64.img 10G
  sudo virsh pool-refresh default
  ```
  Sus nombres se pueden cambiar con las variables `base_image_debian` y `base_image_ubuntu`.
- La clave privada `~/.ssh/id_rsa`, cuya pública está en los `cloud-init/user-data-*`.

## Despliegue

```bash
cd opentofu
tofu init                      # solo la primera vez
tofu apply                     # crea el escenario y genera ../ansible/hosts

cd ../ansible
ansible-playbook site.yaml
```

El orden del playbook es importante: `almacen` (NFS) se configura **antes** que los backends `web`,
porque estos montan desde él su DocumentRoot.

Para entrar a la aplicación, se usa la IP del **balanceador** en la red NAT (la muestra `tofu output`).
Opcionalmente, se añade un nombre en el `/etc/hosts` del anfitrión apuntando a esa IP:

```
192.168.210.X   www.jesusfigueroa.org
```

## Comprobaciones

```bash
tofu output                    # IP de las máquinas
cat ../ansible/hosts           # inventario generado (web1, web2, balanceador, almacen, bd)
ansible-playbook site.yaml     # segunda ejecución: changed=0

# El almacenamiento compartido: el recurso NFS está exportado y los web lo montan.
ssh debian@<ip_nat_almacen> "showmount -e localhost"      # muestra /var/www/guestbook
ssh debian@<ip_nat_web1>    "mount | grep guestbook"      # nfs sobre /var/www/guestbook

# El balanceo: varias peticiones al balanceador caen alternando entre web1 y web2.
# Se ve el reparto en la página de estadísticas de HAProxy:
#   http://<ip_nat_balanceador>:8404/
```
