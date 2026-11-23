# Proyecto 1: Infraestructura como código — Modificaciones 1, 2 y 3 (Balanceo HAProxy + Almacenamiento compartido NFS + Red muy aislada con el balanceador de router)

Escenario creado con **OpenTofu** (libvirt/KVM) y configurado con **Ansible** que pone en producción la aplicación [guestbook_php](https://github.com/josedom24/guestbook_php) (PHP + MariaDB).

**Modificación 1 (balanceo):** se añade un servidor web (de uno a **dos backends**, `web1` y `web2`) y una máquina `balanceador` con **HAProxy** que reparte el tráfico entre ellos en *round-robin*.

**Modificación 2 (almacenamiento compartido):** se añade una máquina `almacen` con un **servidor NFS** que exporta el **DocumentRoot** de la aplicación. Los dos backends ya no guardan una copia propia de la web: la **montan por NFS** desde `almacen`, así se despliega la aplicación una sola vez y ambos sirven exactamente el mismo contenido (una única fuente de verdad).

**Modificación 3 (red muy aislada + balanceador de router):** se les quita la interfaz de red NAT a los **dos backends**, al **servidor de almacenamiento** y al **servidor de base de datos**, de modo que la red de datos pasa a ser una red totalmente aislada. El `balanceador` hace de **router** y da salida a Internet a esas máquinas mediante **SNAT** (`MASQUERADE`): reenvío de paquetes IPv4 activado y enmascaramiento de `10.0.0.0/24` hacia su interfaz NAT. Las máquinas aisladas tienen su ruta por defecto hacia el balanceador (`10.0.0.30`) y DNS `1.1.1.1`. Como ya no son accesibles por NAT desde el anfitrión, Ansible llega a ellas por su IP de datos saltando por el balanceador (`ProxyJump`).

## Escenario

```
                         Anfitrión
                             │ red NAT p1-red-nat 192.168.210.0/24 (DHCP)
                     ┌───────┴────────┐
                     │   balanceador  │  HAProxy (entrada) + router (SNAT)
                     │   ens3 → NAT    │
                     └───────┬────────┘ ens4 10.0.0.30  (gateway de la red de datos)
                             │
  p1-red-datos (muy aislada) · 10.0.0.0/24 · sin DHCP · el anfitrión no tiene IP
     ┌─────────────┬─────────┴──────┬─────────────────┐
     │ 10.0.0.11   │ 10.0.0.12      │ 10.0.0.40        │ 10.0.0.20
┌────┴─────┐  ┌────┴─────┐   ┌──────┴──────┐   ┌───────┴───────┐
│   web1   │  │   web2   │   │   almacen   │   │      bd       │
│Apache+PHP│  │Apache+PHP│   │ NFS DocRoot │   │    MariaDB    │
└────┬─────┘  └────┬─────┘   └──────┬──────┘   └───────────────┘
     └─ montan NFS ┴────────────────┘
```

- `web1`, `web2`, `almacen` y `bd`: una sola interfaz, en la red de datos, **sin NAT**. Su salida a Internet (para `apt`) la da el balanceador por SNAT, y Ansible entra a ellas por `ProxyJump` a través del balanceador.

| Máquina | Imagen | Red NAT (ens3) | Red de datos | Grupo de Ansible | Acceso de Ansible |
|---|---|---|---|---|---|
| balanceador | Debian 13 | DHCP | 10.0.0.30 | `servidores_balanceador` | directo (NAT) |
| web1 | Debian 13 | — | 10.0.0.11 | `servidores_web` | ProxyJump por el balanceador |
| web2 | Debian 13 | — | 10.0.0.12 | `servidores_web` | ProxyJump por el balanceador |
| almacen | Debian 13 | — | 10.0.0.40 | `servidores_almacen` | ProxyJump por el balanceador |
| bd  | Ubuntu 26.04 | — | 10.0.0.20 | `servidores_bd` | ProxyJump por el balanceador |

El anfitrión solo habla con el **balanceador** (red NAT); HAProxy reparte hacia `web1` y `web2`, que sirven la aplicación montada por **NFS** desde `almacen`. Todo el tráfico de datos (balanceo, NFS y BD) va por la **red de datos**, aislada, y la salida a Internet de las máquinas aisladas pasa por el balanceador.

## Estructura del repositorio

```
opentofu/
├── provider.tf              providers libvirt (0.8.3) y local
├── variables.tf             pool, imágenes base y memoria de las máquinas
├── network.tf               red NAT con DHCP y red de datos muy aislada
├── main.tf                  web (for_each: web1/web2), balanceador, almacen y bd
├── output.tf                nombre e IP de cada máquina
├── inventario.tf            genera ../ansible/hosts a partir de inventario.tftpl
├── inventario.tftpl         (web1/web2/almacen/bd entran por ProxyJump por el balanceador)
└── cloud-init/              un YAML por máquina (user-data y network-config)
ansible/
├── ansible.cfg
├── site.yaml                el balanceador se configura el primero (router)
├── group_vars/all           nombres, IP, backends, NFS, usuarios, contraseñas y router
└── roles/
    ├── commons/             actualiza el sistema, paquetes comunes, /etc/hosts
    ├── bd/                  MariaDB, base de datos, usuario (desde los dos web) y tablas
    ├── nfs/                 servidor NFS + despliegue único de la aplicación (files/app/)
    ├── web/                 Apache + PHP, virtual host y montaje NFS del DocumentRoot
    └── balanceador/         HAProxy (round-robin) + router (ip_forward + SNAT)
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

El orden del playbook es importante:

- El `balanceador` se configura **el primero**: hace de router y da salida a Internet (SNAT) a las
  máquinas aisladas, que la necesitan para que `commons` y los demás roles puedan instalar paquetes con `apt`.
- `almacen` (NFS) se configura **antes** que los backends `web`, porque estos montan desde él su DocumentRoot.

Para entrar a la aplicación, se usa la IP del **balanceador** en la red NAT (la muestra `tofu output`).
Opcionalmente, se añade un nombre en el `/etc/hosts` del anfitrión apuntando a esa IP:

```
192.168.210.X   www.jesusfigueroa.org
```

## Comprobaciones

```bash
tofu output                    # IP de las máquinas
cat ../ansible/hosts           # inventario generado (web1/web2/almacen/bd por ProxyJump)
ansible-playbook site.yaml     # segunda ejecución: changed=0

# El balanceador hace de router: reenvío activo y SNAT de la red de datos.
ansible balanceador -b -m shell -a "sysctl -n net.ipv4.ip_forward; iptables -t nat -S POSTROUTING"

# Las máquinas aisladas no tienen NAT pero salen a Internet por el balanceador (SNAT).
ansible web1 -m shell -a "ip -br addr; ip route; ping -c1 1.1.1.1"

# El almacenamiento compartido: el recurso NFS está exportado y los web lo montan.
ansible almacen -b -m shell -a "exportfs -v"           # muestra /var/www/guestbook
ansible web1    -m shell -a "findmnt /var/www/guestbook"

# El balanceo: varias peticiones al balanceador caen alternando entre web1 y web2.
# Se ve el reparto en la página de estadísticas de HAProxy:
#   http://<ip_nat_balanceador>:8404/
```
