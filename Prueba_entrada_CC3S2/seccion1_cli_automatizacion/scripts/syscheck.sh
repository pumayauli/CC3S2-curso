#!/usr/bin/env bash
# Genera reports/{http.txt,dns.txt,tls.txt,sockets.txt}
# Requisitos: curl, dig, ss, jq

set -euo pipefail

# Limpieza segura de temporales
_tmp_dir=""
cleanup() {
  [[ -n "${_tmp_dir}" && -d "${_tmp_dir}" ]] && rm -rf "${_tmp_dir}"
}
trap cleanup EXIT INT TERM

# Rutas base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORTS_DIR="${BASE_DIR}/reports"
mkdir -p "${REPORTS_DIR}"

# Temp
_tmp_dir="$(mktemp -d)"

note() { printf "%s\n" "$*" >&2; }

#############################################
# 1) HTTP: cabeceras + explicación de código
#############################################
HTTP_OUT="${_tmp_dir}/http_raw.txt"
note "[HTTP] Consultando cabeceras de https://example.com ..."
# -I: solo cabeceras, -s silencioso, -S errores a stderr, -L sigue redirecciones (por si acaso)
curl -ILsS "https://example.com" > "${HTTP_OUT}" || true

# Extraer el último código HTTP visto (última respuesta tras redirecciones)
HTTP_CODE="$(awk '/^HTTP\//{code=$2} END{print code+0}' "${HTTP_OUT}" 2>/dev/null || echo 0)"

{
  echo "===== curl -Is https://example.com ====="
  cat "${HTTP_OUT}"
  echo
  echo "----- Explicación -----"
  echo "Código HTTP observado: ${HTTP_CODE}"
  case "${HTTP_CODE}" in
    200) echo "200 OK: el servidor respondió correctamente a la solicitud.";;
    301|308) echo "${HTTP_CODE} Redirect: el recurso fue movido; el cliente siguió la redirección.";;
    302|307) echo "${HTTP_CODE} Redirect temporal: el recurso puede estar en otra URL temporalmente.";;
    404) echo "404 Not Found: el recurso solicitado no existe en el servidor.";;
    500) echo "500 Internal Server Error: fallo del servidor al procesar la solicitud.";;
    0|"") echo "No se pudo determinar el código (¿sin conexión o bloqueo de red?).";;
    *) echo "Código ${HTTP_CODE}: revisar semántica exacta en la especificación HTTP.";;
  esac
} > "${REPORTS_DIR}/http.txt"

#############################################
# 2) DNS: A/AAAA/MX + comentario de TTL
#############################################
DNS_OUT="${_tmp_dir}/dns_raw.txt"
note "[DNS] Consultando registros A/AAAA/MX de example.com ..."
# Formato ANSWER únicamente
{
  echo "===== dig A example.com +noall +answer ====="
  dig A example.com +noall +answer
  echo
  echo "===== dig AAAA example.com +noall +answer ====="
  dig AAAA example.com +noall +answer
  echo
  echo "===== dig MX example.com +noall +answer ====="
  dig MX example.com +noall +answer
} > "${DNS_OUT}"

# Intentar extraer un TTL de la primera línea con respuesta
TTL_VAL="$(awk 'NF>=5 {print $2; exit}' "${DNS_OUT}" 2>/dev/null || true)"

{
  cat "${DNS_OUT}"
  echo
  echo "----- Comentario TTL -----"
  if [[ -n "${TTL_VAL}" ]]; then
    echo "TTL observado (segundos): ${TTL_VAL}"
    echo "El TTL indica cuánto tiempo un resolver puede *cachear* esta respuesta antes de volver a consultar."
  else
    echo "No se pudo extraer un TTL (posible ausencia de respuesta o red restringida)."
  fi
} > "${REPORTS_DIR}/dns.txt"

#############################################
# 3) TLS: versión observada
#############################################
TLS_OUT="${_tmp_dir}/tls_raw.txt"
note "[TLS] Intentando detectar versión TLS vía curl -Iv ..."
# La línea suele contener "SSL connection using TLSv1.3" o similar
curl -Iv "https://example.com" -sS 2>&1 | tee "${TLS_OUT}" >/dev/null || true

TLS_LINE="$(grep -iE 'SSL connection|TLSv' "${TLS_OUT}" | head -n1 || true)"
TLS_VER="$(echo "${TLS_LINE}" | grep -oE 'TLSv[0-9]\.[0-9]+' || true)"

{
  echo "===== curl -Iv https://example.com ====="
  cat "${TLS_OUT}"
  echo
  echo "----- Versión TLS observada -----"
  if [[ -n "${TLS_VER}" ]]; then
    echo "Versión TLS detectada: ${TLS_VER}"
    echo "TLS provee confidencialidad e integridad; modernamente se prefiere TLS 1.2 o 1.3."
  else
    echo "No se pudo detectar la versión TLS (línea no encontrada o bloqueo de red)."
  fi
} > "${REPORTS_DIR}/tls.txt"

#############################################
# 4) Sockets locales: puertos abiertos
#############################################
SOCK_OUT="${_tmp_dir}/sockets_raw.txt"
note "[SOCKETS] Listando puertos locales con ss -tuln ..."
ss -tuln > "${SOCK_OUT}" 2>/dev/null || true

{
  echo "===== ss -tuln ====="
  cat "${SOCK_OUT}"
  echo
  echo "----- Riesgos comunes -----"
  echo "1) Servicios innecesarios expuestos aumentan la superficie de ataque (escaneo y explotación)."
  echo "2) Puertos abiertos sin hardening (auth/cifrado/patching) pueden filtrar datos o permitir acceso no autorizado."
} > "${REPORTS_DIR}/sockets.txt"

note "Reportes generados en: ${REPORTS_DIR}/"
