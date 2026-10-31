# Proyecto 1: Infraestructura como código

Escenario creado con **OpenTofu** (libvirt/KVM) y configurado con **Ansible** que pone en producción la aplicación [guestbook_php](https://github.com/josedom24/guestbook_php) (PHP + MariaDB).

## Escenario

```
                 Anfitrión
                     │ 192.168.210.1
     ┌───────────────┴────────────────┐
     │  p1-red-nat (NAT + DHCP)        │  192.168.210.0/24
     └──────┬──────────────────┬──────┘
       ens3 │ DHCP        ens3 │ DHCP
     ┌──────┴──────┐    ┌──────┴──────┐
     │     web     │    │     bd      │
     │ Apache+PHP  │    │   MariaDB   │
     └──────┬──────┘    └──────┬──────┘
       ens4 │ 10.0.0.10   ens4 │ 10.0.0.20
     ┌──────┴──────────────────┴──────┐
     │  p1-red-datos (muy aislada)     │  10.0.0.0/24 · sin DHCP ·
     └────────────────────────────────┘  el anfitrión no tiene IP
```

| Máquina | Imagen | Red NAT (ens3) | Red de datos (ens4) | Grupo de Ansible |
|---|---|---|---|---|
| web | Debian 13 | DHCP | 10.0.0.10 | `servidores_web` |
| bd  | Ubuntu 26.04 | DHCP | 10.0.0.20 | `servidores_bd` |

## Estructura del repositorio

```
opentofu/
├── provider.tf              providers libvirt (0.8.3) y local
├── variables.tf             pool, imágenes base y memoria de las máquinas
├── network.tf               red NAT con DHCP y red de datos muy aislada
├── main.tf                  web y bd: disco (clon ligero), ISO de cloud-init y máquina
├── output.tf                nombre e IP (NAT y datos) de cada máquina
├── inventario.tf            genera ../ansible/hosts a partir de inventario.tftpl
├── inventario.tftpl
└── cloud-init/              user-data-web.yaml, network-config-web.yaml, user-data-bd.yaml, network-config-bd.yaml
ansible/
├── ansible.cfg
├── site.yaml
├── group_vars/all           nombres, IP, usuarios y contraseñas
└── roles/
    ├── commons/             actualiza el sistema, paquetes comunes, /etc/hosts
    ├── bd/                  MariaDB, base de datos, usuario y tablas (files/schema.sql)
    └── web/                 Apache + PHP, virtual host y aplicación (files/app/)
```

## Requisitos

- KVM/libvirt, OpenTofu y Ansible (con las colecciones `community.mysql` y `community.general`;
  el paquete `ansible` de Debian ya las trae).
- Las imágenes base en el pool `default` (las máquinas son clones ligeros de ellas):
  - `web` → Debian 13: `debian-13-generic-amd64.qcow2`
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
- La clave privada `~/.ssh/id_rsa`, cuya pública está en `cloud-init/user-data-*.yaml`.

## Despliegue

```bash
cd opentofu
tofu init                      # solo la primera vez
tofu apply                     # crea el escenario y genera ../ansible/hosts

cd ../ansible
ansible-playbook site.yaml
```

Para entrar a la aplicación por su nombre, se añade en el `/etc/hosts` del anfitrión la IP de `web`
en la red NAT (la muestra `tofu output`):

```
192.168.210.X   www.jesusfigueroa.org
```

## Comprobaciones

```bash
tofu output                    # IP de las máquinas
cat ../ansible/hosts           # inventario generado
ansible-playbook site.yaml     # segunda ejecución: changed=0

# Desde web: funciona
ssh debian@<ip_nat_web> "mysql -h 10.0.0.20 -u guestbook_user -pguestbook_pass guestbook_db -e 'SELECT * FROM messages'"

# Desde bd (otra IP): se rechaza  →  Host '10.0.0.20' is not allowed to connect to this MariaDB server
ssh ubuntu@<ip_nat_bd> "mysql -h 10.0.0.20 -u guestbook_user -pguestbook_pass guestbook_db"
```
