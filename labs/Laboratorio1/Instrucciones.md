### Laboratorio: HTTP + DNS + TLS para DevOps/DevSecOps con Make

Este laboratorio te guía por HTTP, DNS (A/AAAA, CNAME, TXT, MX, SRV), TTL y cachés, y TLS de forma reproducible.  
Integra `curl`, `dig`, `ss`, `openssl`, `lsof`, `ip`, `getent`, `resolv.conf`, Netplan (IP estática), UFW, Nginx (reverse proxy) y una unidad de systemd.  
La aplicación sigue la metodología **12-Factor App** (configuración por variables de entorno, port binding, logs como flujos).


#### Conceptos tratados

- **HTTP como contrato observable:** La app expone `/` con estado, mensaje y versión, y escribe **logs a stdout**. Esto facilita monitoreo y depuración. Se respetan los **métodos** e **idempotencia** para reintentos y *health checks*.
- **12-Factor App (extracto):** Configuración por **variables de entorno** (`PORT`, `MESSAGE`, `RELEASE`), **port binding** (la app escucha en el puerto), y **logs como flujos** (stdout). Estas prácticas simplifican despliegues y evitan acoplar configuración al código.
- **DNS y caché:** Se utilizan entradas de `hosts` para `miapp.local` y comandos (`dig`) para observar **TTL** y comportamiento de caché. El *resolver* local reduce latencias y centraliza políticas.
- **TLS y reverse proxy:** Nginx termina TLS en `:443`, reenvía tráfico a la app Flask en `127.0.0.1:8080` y añade cabeceras `X-Forwarded-*`. Se emplean **certificados autofirmados** solo para laboratorio.
- **Firewall y servicios:** `ufw` puede permitir `443/tcp`; `systemd` (o `service` en WSL) controla procesos en segundo plano.  
- **Diagnóstico operativo:** `ss` para puertos, `openssl s_client` para el apretón de manos TLS, `curl` para validar respuestas HTTP/HTTPS y `journalctl`/logs de Nginx para errores.

> Con ello se integran **aplicación**, **red** (DNS/hosts), **seguridad** (TLS), y **operación** (systemd/servicios) en un flujo reproducible con `make` tanto en Linux nativo como en Windows+WSL.

#### Requisitos previos
Sistema tipo Ubuntu/Debian con: `python3-venv`, `nginx`, `ufw` (opcional), `dnsutils` (para `dig`), `lsof`, `iproute2`, `openssl`.

#### Inicio rápido
```bash
make help
make prepare
make hosts-setup
make run               # mantener en una terminal
# nueva terminal:
make check-http
make tls-cert
sudo systemctl restart nginx || true   # asegura que nginx esté ejecutándose
make nginx
make ufw-open
make check-tls
make dns-demo
```

#### Guía por sistema operativo (paso a paso)

#### A) Linux (Ubuntu/Debian nativo)
> **Requisitos**: `python3-venv`, `nginx`, `dnsutils`, `lsof`, `iproute2`, `openssl` (y opcionalmente `ufw`).  
> **Notas**: Requiere permisos de `sudo` para tareas que tocan `/etc` (nginx, hosts, certificados).

1. **Clonar y abrir el proyecto**
   ```bash
   git clone <URL_DEL_REPO>/labs && cd Laboratorio1
   ```
2. **Preparar entorno y ejecutar la app Flask**
   ```bash
   make help
   make prepare
   make hosts-setup
   make run      # deja esta terminal abierta mostrando logs
   ```
3. **Verificar HTTP en local**
   ```bash
   make check-http
   # o manualmente:
   curl -i http://127.0.0.1:8080/
   ```
4. **Generar certificados y configurar Nginx (reverse proxy + TLS)**
   ```bash
   make tls-cert
   sudo systemctl restart nginx || true
   make nginx
   ```
5. **Abrir el puerto (opcional)**
   ```bash
   # si usas UFW:
   sudo ufw allow 443/tcp
   ```
6. **Comprobar HTTPS**
   ```bash
   make check-tls
   # o manualmente:
   openssl s_client -connect miapp.local:443 -servername miapp.local -brief
   curl -k https://miapp.local/
   ```
7. **Demostración DNS y caché**
   ```bash
   make dns-demo
   ```
8. **Servicio en segundo plano (opcional)**
   ```bash
   # si el Makefile incluye el target:
   sudo make systemd-install
   systemctl status miapp
   ```
9. **Limpieza (opcional)**
   ```bash
   make cleanup
   ```

> **Diagnóstico útil (Linux):**  
> - `ss -tlpn | grep -E ':(8080|443)'` - ver puertos en uso.  
> - `journalctl -u nginx --no-pager -n 100` - logs de Nginx.  
> - `tail -f /var/log/nginx/error.log` - errores de Nginx.  
> - `dig +short miapp.local` - resolución local de hosts.


#### B) Windows 10/11 + WSL2 (Ubuntu) + Visual Studio Code (Remoto WSL)
> Ejecutaremos **todo dentro de WSL (Ubuntu)** y editaremos el código con **VS Code** usando la extensión *WSL*.  
> Esto evita problemas de rendimiento y rutas cuando el proyecto está en `C:` (que aparece como `/mnt/c/` dentro de WSL).

1. **Instalar WSL + Ubuntu (si no lo tienes)**
   - Abre PowerShell (Administrador) y ejecuta:
     ```powershell
     wsl --install -d Ubuntu
     ```
   - Reinicia si es necesario y completa la creación de tu usuario en Ubuntu.

2. **Instalar VS Code (Windows) y la extensión *WSL***
   - Instala **Visual Studio Code** desde su sitio oficial.
   - Dentro de VS Code, instala la extensión **WSL** (ID: `ms-vscode-remote.remote-wsl`).

3. **Abrir una ventana de VS Code conectada a WSL**
   - Presiona `Ctrl+Shift+P` -> **“WSL: New WSL Window”**.
   - En esa ventana (verde), **Open Folder...** y elige una carpeta en **WSL**, por ejemplo: `/home/<tu_usuario>/proyectos`.

4. **Copiar o clonar el proyecto dentro de WSL (evitar `/mnt/c`)**
   - Si lo tienes en Windows:  
     ```bash
     mkdir -p ~/Curso-CC3S2/labs
     cp -r /mnt/c/Users/<tu_usuario>/Curso-CC3S2/labs/Laboratorio1 ~/Curso-CC3S2/labs/
     cd ~/Curso-CC3S2/labs/Laboratorio1
     ```
   - O clónalo directamente en WSL:  
     ```bash
     git clone <URL_DEL_REPO> ~/Curso-CC3S2/labs/Laboratorio1
     cd ~/Curso-CC3S2/labs/Laboratorio1
     ```

5. **Instalar paquetes y ejecutar (igual que en Linux)**
   ```bash
   make help
   make prepare
   make hosts-setup
   make run      # deja esta terminal abierta
   # en una nueva terminal de VS Code (WSL):
   make check-http
   make tls-cert
   sudo service nginx start || true   # si no tienes systemd en WSL
   make nginx
   make check-tls
   ```

6. **Ver el sitio desde Windows con `https://miapp.local/`**
   - Edita el archivo **hosts de Windows** (como Administrador):  
     `C:\Windows\System32\drivers\etc\hosts`  
     Agrega esta línea si no existe:  
     ```
     127.0.0.1 miapp.local
     ```
   - Abre tu navegador de Windows y visita **https://miapp.local/**.  
     Al ser un certificado autofirmado, el navegador pedirá confirmación.

7. **(Opcional) Habilitar systemd en WSL**
   - En WSL, crea/edita `/etc/wsl.conf` con:
     ```ini
     [boot]
     systemd=true
     ```
   - En Windows, ejecuta:
     ```powershell
     wsl --shutdown
     ```
   - Vuelve a abrir WSL. Ahora puedes usar `systemctl` dentro de WSL.

> **Diagnóstico útil (WSL):**  
> - `ss -tlpn` dentro de WSL para puertos 8080/443.  
> - `curl -k https://miapp.local/` desde WSL y desde Windows para comparar.  
> - Si el navegador de Windows no resuelve `miapp.local`, revisa el *hosts de Windows* (no el de WSL).

