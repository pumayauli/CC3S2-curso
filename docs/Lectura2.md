## HTTP, DNS, TLS y herramientas de diagnóstico (curl, dig, ss, openssl)

En DevOps, la **disponibilidad** no depende solo del código, sino de cómo resolvemos nombres (DNS), cómo transportamos y protegemos el tráfico (TLS) y cómo definimos contratos y políticas de caché (HTTP).
En DevSecOps, estos mismos puntos son superficies de control para integridad, confidencialidad, trazabilidad y cumplimiento.
Las herramientas **curl, dig, ss** y **openssl** actúan como estetoscopios de red para verificar hipótesis de salud y seguridad sin introducir ruido ni depender de terceros.

### HTTP: contrato, rendimiento y gobernanza operativa

**Rol en DevOps.** HTTP es el "idioma" de la mayoría de microservicios expuestos al exterior y de APIs internas tras gateways. 
En producción, los tiempos de respuesta (p50/p95), los códigos de estado y los encabezados definen el contrato observable del servicio. 
Idempotencia (GET, PUT) y semántica de métodos (POST, PATCH, DELETE) influyen en reintentos y estrategias de **[circuit breaking](https://medium.com/@goguzgungor59/circuit-breaker-pattern-and-implementation-guide-f4bd0eb7010f)**.

**Versiones y transporte.**

* **HTTP/1.1**: conexiones persistentes y *pipelining* limitado, con riesgo de *head-of-line blocking* a nivel de conexión.
* **HTTP/2**: multiplexación real sobre una sola conexión, compresión de encabezados (HPACK), mejor utilización de ancho de banda y latencia efectiva menor.
* **HTTP/3**: ejecuta HTTP sobre **QUIC** (UDP), mitigando *head-of-line* del TCP y mejorando recuperación ante pérdida de paquetes; útil en redes inestables o móviles.

**Caché y control de tráfico.** Encabezados como *Cache-Control*, *ETag* y *Last-Modified* definen modelos de revalidación. 
En CDNs y *edge*, la táctica de **caché por defecto segura** con invalidación explícita reduce coste y picos. 
Para APIs, la caché suele focalizarse en GET y en consultas que no exponen datos sensibles. Considerar **variantes por encabezados** (idioma, *user-agent*) y **content negotiation** (Accept) para evitar *cache poisoning*.

**Observabilidad.** Logs de acceso con dimensiones (método, ruta, código, latencia, tamaño de respuesta) y trazas distribuidas con **correlación** (*trace-id*, *span-id*) permiten aislar cuellos de botella. 
La propagación de contexto (p. ej., encabezados W3C Trace Context) unifica análisis entre servicios. 
Incluir métricas de **saturación** (cola, *concurrency*) junto con *SLI* de latencia p95/p99 y *error rate* por familia de códigos.

**Seguridad en el plano HTTP.** Endurecer **headers de seguridad** (CSP, X-Frame-Options, X-Content-Type-Options, HSTS), validar tamaños y formatos, y gestionar límites por cliente protege contra abusos. 
En **[zero trust](https://www.akamai.com/es/glossary/what-is-zero-trust)** interno, se combina con autenticación en gateway y **mTLS** servicio-a-servicio. 
Evitar **mezcla de contenido** (HTTP en páginas HTTPS) y definir políticas de **rate limiting** y **bot management** en el borde.

**Prácticas de entrega.** En **Make** y pipelines, las etapas de validación funcional de endpoints (sin revelar secretos) y verificación de encabezados críticos se automatizan para evitar regresiones operativas. 
La política de *timeouts*, reintentos con *exponential backoff* y límites de concurrencia debe declararse y versionarse como parte del contrato del servicio. 
Añadir pruebas de **degradación controlada** (latencia inyectada, respuestas 429/503) para validar resiliencia.

### DNS: la capa de descubrimiento y resiliencia

**Rol en DevOps.** DNS mapea nombres a direcciones IP y, cada vez más, a objetivos lógicos (balanceadores, *service discovery*, registros SRV). 
Es el primer eslabón de disponibilidad: una entrada mal configurada o una TTL inadecuada puede bloquear por completo un despliegue o hacer imposible un *rollback* rápido.

**Componentes y flujo.** La resolución involucra *resolvers* recursivos, servidores autoritativos y cachés intermedias. 
La estrategia de **TTL** condiciona la velocidad de propagación de cambios: TTLs cortas agilizan *rollbacks* pero aumentan consultas y latencia, TTLs largas ahorran recursos pero endurecen la reversión. 
Considerar **caché negativa** (NXDOMAIN) y su TTL, pues prolonga errores.

**Registros clave.** A/AAAA para direccionamiento; **CNAME** para alias; **TXT** para verificaciones (incluida automatización de certificados); **SRV** para descubrimiento de servicios; **NS** para delegación; **CAA** para limitar emisores de certificados. 
En dominios *apex* (raíz), considerar soluciones que simulen alias (según proveedor) si se requiere apuntar al mismo objetivo que un CNAME.

**Seguridad y control.** **DNSSEC** añade firma de registros (integridad), aunque no cifra el canal. En redes internas, **split-horizon DNS** habilita respuestas diferenciadas por origen (interno/externo). 
Evaluar **DoT/DoH** (DNS sobre TLS/HTTPS) para privacidad en clientes; en entornos corporativos, balancear con necesidades de observabilidad. 
El gobierno de zonas debe formar parte de IaC con *reviews* y auditoría (quién, cuándo, por qué cambió un registro).

**Operación con despliegues.** Cambios de endpoint por *blue/green* o *canary* deben coordinarse con TTL y ventanas de mantenimiento. 
En pruebas de caos, simular NXDOMAIN o latencia de resolución ayuda a validar tolerancia a fallos. 
La métrica *DNS time-to-first-byte* se incluye en SLO de disponibilidad end-to-end. Incorporar **GeoDNS** o *weighted routing* cuando se requieran migraciones progresivas de tráfico.


### TLS: confidencialidad, integridad y autenticación

**Rol en DevSecOps.** TLS protege el canal entre clientes, *edges* y microservicios. Más allá del cifrado, representa **identidad** gracias a certificados y cadenas de confianza. En TLS 1.3 se simplifican *handshakes* y se prioriza **PFS** (secreto perfecto hacia adelante) con suites de curva elíptica.

**Diseños comunes.**

* **Terminación en el borde** (load balancer o Ingress): cifra en el exterior y decide si continuar cifrado o no aguas adentro.
* **mTLS interno**: ambos extremos se autentican; útil en mallas de servicio y *zero trust*.
* **Passthrough**: el borde enruta sin terminar TLS; el servicio final responde con su propio certificado.

**Ciclo de vida de certificados.** Emisión (a menudo automatizada), renovación proactiva, rotación segura de cadenas y validación de revocación (OCSP *stapling* donde aplique). 
Políticas de **ciphers** y versiones mínimas deben ser explícitas y probadas con cada *release*. 
Monitorizar **días hasta la expiración**, tamaño y tipo de clave (RSA/ECDSA) y **SANs** exigidos.

**Rendimiento y riesgos.** Considerar **resumption** y **session tickets** para reducir latencia, y evaluar **0-RTT** (posibles *replays* de tráfico no idempotente). 
Evitar *fallbacks* inseguros, comodines excesivos y claves compartidas entre entornos. Usar **Certificate Transparency** para vigilar emisiones inesperadas. 
Verificar consistencia entre SNI, *hostname* y cadena completa para prevenir errores de validación.

### Herramientas clínicas de red: curl, dig, ss y openssl

**curl: verificación funcional y de contrato.**
Permite observar la respuesta de un endpoint, sus encabezados, tiempos de resolución, negociación de protocolo (HTTP/1.1, HTTP/2, HTTP/3) y detalles de la sesión TLS. Útil para:

* Confirmar códigos de estado, redirecciones y encabezados de caché.
* Auditar *security headers* y tamaño de respuestas frente a límites definidos.
* Comparar latencias entre *edges* o zonas, y validar *health checks* de balanceadores.
* Comprobar negociación **ALPN** (HTTP/2 vs HTTP/1.1) y presencia de **HSTS**.

**dig: evidencia de resolución y propagación.**
Sirve para interrogar servidores autoritativos o *resolvers* específicos, comparar respuestas en distintas ubicaciones y observar TTLs remanentes. Casos típicos:

* Investigar por qué un canario no recibe tráfico tras un cambio DNS.
* Validar la existencia y firma de registros (cuando DNSSEC es relevante).
* Medir tiempos de respuesta de resolutores y detectar *timeouts* intermitentes.
* Revisar **CAA** antes de solicitar certificados y **TXT** para automatizaciones.

**ss: estado de sockets y puertos en el host.**
Proporciona visibilidad de puertos abiertos, estados de conexión (colas de escucha, *SYN-RECV*, *TIME\_WAIT*), y métricas de congestión. Escenarios:

* Distinguir saturación de *backlog* de escucha frente a agotamiento de CPU.
* Detectar acumulación de conexiones en espera de *handshake* TLS o *TIME\_WAIT* excesivo por política de *keep-alive*.
* Asegurar que servicios expuestos respetan el modelo de **port binding** acordado con la plataforma.

**openssl: inspección criptográfica y de cadena de confianza.**
Permite examinar **cadena de certificados**, protocolos y *ciphers* negociados, **SNI**, **ALPN**, **OCSP stapling** y **fechas de validez**. Útil para:

* Verificar que el servidor presenta la **cadena completa** y que los **SANs** incluyen el nombre solicitado.
* Comprobar **versión mínima de TLS** aceptada y conjuntos de **cifrado** permitidos según política.
* Inspeccionar **OCSP stapling** para revocación en vivo y **resumen** de claves (tamaño, algoritmo).
* Evaluar **tiempos de *handshake*** de forma comparativa y validar que mTLS exige y presenta certificados cliente cuando corresponde.

### Conexión con Linux/Bash, Make y automatización

El flujo recomendado es **definir** contratos observables (HTTP), **gobernar** el descubrimiento (DNS) y **proteger** el transporte (TLS), y convertir todo en **tareas reproducibles**. 
En **Bash/Make**, esos pasos se transforman en actividades declarativas: validar endpoints externos e internos, comprobar registros DNS críticos antes de promover, inspeccionar estados de puertos del *runtime* tras *rollouts*. 
La clave es que cada verificación produzca **evidencias**: tiempos, encabezados, métricas de sockets y conclusiones operativas.

Para DevSecOps, se añaden verificaciones de **política**: versiones mínimas de protocolo, suites de cifrado permitidas, *headers* obligatorios, y rechazos automáticos de despliegue cuando el contrato de seguridad no se cumple. 
Estas reglas deben alinearse con el **[risk appetite](https://www-logicmanager-com.translate.goog/resources/erm/risk-appetite-risk-tolerance-residual-risk/?_x_tr_sl=en&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=tc)** institucional y con normativas aplicables. Integrar controles de **expiración de certificados**, **CAA** coherentes, **HSTS** correcto y **DNSSEC** cuando aplique. 
Incluir chequeos de **ALPN** y versiones de HTTP efectivamente negociadas para evitar degradaciones silenciosas.

### Recomendaciones de evaluación y práctica

**Resultados de aprendizaje sugeridos.**

1. Interpretar latencia separando componentes: resolución DNS, *handshake* TLS, tiempo de cola en balanceador y procesamiento HTTP.
2. Diseñar políticas de caché y de *timeouts/retries* coherentes con SLOs y validar su impacto en p95/p99.
3. Documentar y versionar decisiones de TLS (política de ciphers, rotación, terminación vs mTLS) y su impacto en el rendimiento.
4. Definir métricas operativas mínimas: *availability*, *error rate*, latencia p95, errores por tipo (DNS/HTTP/TLS), y estados de sockets durante *rollouts*.
5. Integrar verificaciones de contrato y seguridad a Make/pipelines con artefactos de evidencia (sin exponer secretos).
6. Establecer umbrales de **días a expiración** de certificados y alarmas; revisar **CT logs** para detectar emisiones no autorizadas.
7. Practicar **simulaciones de incidente** (resolución intermitente, certificado expirado, degradación HTTP/2->1.1) con análisis postmortem.

**Antipatrones a evitar.**

* TTL de DNS rígidos en despliegues con *rollback* frecuente o *canary*.
* Dejar TLS sin política vigente, permitir versiones obsoletas o comodines excesivos.
* *Gateways* sin límites ni validación de encabezados, o ausencia de **HSTS** en sitios públicos.
* Falta de correlación de trazas entre servicios y métricas inconexas.
* Diagnósticos manuales sin registro de evidencias ni repetibilidad.
* Ignorar **SAN mismatches**, usar IPs "pegadas" en clientes o desactivar validación TLS.
* No contemplar **caché negativa** de DNS y su TTL durante *rollbacks*.


Las capas **HTTP, DNS y TLS** deben tratarse como parte del diseño de producto, no solo como configuración de plataforma. La disciplina de **DevOps/DevSecOps** exige que cada decisión de red esté respaldada por automatización, observabilidad y gobernanza. Con contratos HTTP claros, descubrimiento robusto vía DNS, transporte cifrado y autenticado con TLS, y un uso disciplinado de **curl, dig, ss y openssl**, los equipos pueden sostener sistemas **resilientes, auditables y escalables** a lo largo de su ciclo de vida.
