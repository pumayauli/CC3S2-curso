### 12-Factor App

La metodología **12-Factor App** reúne principios de diseño y operación que favorecen aplicaciones **escalables, mantenibles y resilientes**, alineadas con prácticas modernas de entrega continua, contenedores y orquestadores. 
Para DevOps, estos factores se traducen en decisiones diarias sobre cómo organizar repositorios, declarar dependencias, gestionar configuración, acoplar servicios, separar etapas
de *build/release/run*, operar procesos sin estado, exponer puertos, escalar horizontalmente, iniciar y detener servicios con rapidez, mantener paridad entre entornos, emitir logs como flujos y ejecutar tareas administrativas de forma controlada. 

Incorporar **DevSecOps** añade controles de seguridad "*shift-left*" (SAST, SCA), gobierno de dependencias y secretos, firma de artefactos, *policy-as-code*, escaneo dinámico y trazabilidad de la cadena de suministro. 

A continuación, se detallan los 12 factores y su aterrizaje operativo con DevSecOps.

#### 1) Codebase = Un solo repositorio por aplicación

**Concepto.** Cada aplicación mantiene **una única base de código** versionada. Un microservicio = un repositorio.

**Prácticas recomendadas.** Un repositorio por servicio (por ejemplo, `user-service`, `payment-service`), con *branch protection*, *pull requests* y *code reviews*. Evitar dividir una misma app en múltiples repos innecesarios, la modularidad puede resolverse con *packages* y mono-repos correctamente gobernados, si se justifican.

**Ejemplo DevOps.** Pipelines de CI/CD por repositorio: construcción de imágenes, pruebas, publicación y despliegue a *Dev/QA/Prod* con promoción entre ambientes.

**Enfoque DevSecOps.** Reglas de protección en ramas, **SAST** por PR, políticas de *commit signing*, verificación de autoría y *CODEOWNERS*. Auditoría de cambios, obligatoriedad de *status checks* (pruebas, lint, seguridad) para fusionar.

#### 2) Dependencies = Dependencias explícitas

**Concepto.** Todas las dependencias se **declaran** de forma explícita y versionada (`requirements.txt`, `pom.xml`, `package.json`, `Dockerfile`, *lockfiles*).

**Prácticas recomendadas.** Instalar dependencias en el *pipeline* y/o construcción de imagen, usar *cachés* deterministas, fijar rangos o versiones para reproducibilidad. Evitar instalaciones manuales en servidores.

**Ejemplo DevOps.** Etapas de CI que ejecutan `pip install -r requirements.txt`, `mvn install` o `npm ci` dentro de un *builder* o *Dockerfile*, con *cache mounts* para acelerar.

**Enfoque DevSecOps.** **SCA** (escaneo de dependencias) y generación de **SBOM** en *build*, fallar el *pipeline* ante CVEs críticas, reglas de *allow/deny lists* de componentes,  vigilancia de *supply chain* y *typosquatting*.


#### 3) Config = Configuración en variables de entorno

**Concepto.** La **configuración** (URLs, *feature flags*, credenciales) **no** se embebe en el código, se inyecta por **variables de entorno**.

**Prácticas recomendadas.** Separar configuración por entorno (Dev/QA/Prod) y gestionarla con **ConfigMaps/Secrets** en Kubernetes, *parameter stores* o gestores de secretos. Prohibir *hardcode* de secretos.

**Ejemplo DevOps.** Integrar *injectors* de variables en CI, usar *Helm values* para endpoints y llaves, mantener una sola imagen promovida entre ambientes cambiando solo valores.

**Enfoque DevSecOps.** *Secret scanning* en PR, cifrado de secretos (p. ej., **Sealed Secrets** o SOPS),  **OPA/Conftest** para políticas que impidan secretos en claro, rotación periódica y *least privilege*.


#### 4) Backing Services = Servicios como recursos adjuntos

**Concepto.** Bases de datos, colas, *caches* o almacenamiento de objetos se tratan como **recursos adjuntos** y **sustituibles** mediante configuración.

**Prácticas recomendadas.** Acceder a servicios por URL/credenciales inyectadas, diseñar *adapters* para facilitar el intercambio (por ejemplo, cambiar Redis/DB/bucket sin recompilar).

**Ejemplo DevOps.** Cambiar el endpoint de Redis o la cadena de conexión de DB en `values.yaml` sin tocar el binario, usar *provisioners* de Terraform para servicios administrados.

**Enfoque DevSecOps.** TLS para conexiones, autenticación mutua cuando aplique, *policies* de cortafuegos o **NetworkPolicies** en Kubernetes, control de roles en servicios externos y rotación de credenciales.

#### 5) Build, Release, Run = Etapas separadas

**Concepto.** **Build** empaqueta el artefacto, **Release** combina artefacto + configuración/versionado, **Run** ejecuta la *release* en la plataforma.

**Prácticas recomendadas.** No reconstruir en *Release* o *Run*. Trazabilidad de versiones, promoción entre ambientes sin *rebuild*, *immutable artifacts*.

**Ejemplo DevOps.** *Pipeline* con tres etapas:

* *Build*: compilar o crear la imagen.
* *Release*: etiquetar, inyectar configuración y publicar el *manifest*.
* *Run*: desplegar a Kubernetes/ECS con *rollouts* graduales.

**Enfoque DevSecOps.** Firmar artefactos (p. ej., **cosign**), adjuntar **provenance** y cumplir niveles de **SLSA**, *gates* de seguridad antes de *release* (SAST/SCA). **DAST** en *staging* y aprobación basada en riesgo.

#### 6) Processes = Aplicaciones *stateless*

**Concepto.** Los procesos de la app no almacenan estado persistente localmente, el estado va a **servicios duraderos** (DB/Redis/S3).

**Prácticas recomendadas.** Evitar sesiones en memoria/archivo, usar *stores* compartidos, diseñar *idempotencia* en operaciones.

**Ejemplo DevOps.** *Deployments* de Kubernetes con múltiples réplicas, sesiones en Redis, *rollouts* sin pérdida.

**Enfoque DevSecOps.** Reducir superficie de ataque por nodo, facilitar rotación/parcheo de pods, controles de acceso al *store* de estado y cifrado *at-rest*.

#### 7) Port Binding = Servicios autocontenidos

**Concepto.** La aplicación **expone su puerto** (p. ej., 8080) y no depende de *app servers* externos.

**Prácticas recomendadas.** Implementar *health endpoints*, delegar ruteo a **Service/Ingress** o *gateways*, documentar el contrato (ruta/estado/headers).

**Ejemplo DevOps.** Spring Boot con Tomcat embebido, Flask/FastAPI exponiendo `PORT`, Kubernetes gestiona ruteo/descubrimiento.

**Enfoque DevSecOps.** TLS en el Ingress y, si procede, mTLS servicio-a-servicio, *waf* y *rate limiting*, validación de *headers* críticos y *security headers*.

#### 8) Concurrency = Escalamiento horizontal

**Concepto.** Escalar mediante **múltiples instancias** en paralelo.

**Prácticas recomendadas.** Preferir varias réplicas pequeñas, **HPA** por CPU/RAM/latencia, pruebas de carga con *baselines* y SLO/SLI.

**Ejemplo DevOps.** `replicas: 3` en `Deployment`, políticas de *autoscaling* con métricas de aplicación (p. ej., *requests per second*).

**Enfoque DevSecOps.** *Rate limits* y *circuit breakers* para evitar cascadas de fallos, *budgets* de error, controles de abuso y *bot protection* en los bordes.

#### 9) Disposability = Arranque y apagado rápidos (*graceful*)

**Concepto.** La app debe **iniciar y detenerse rápido**, con cierre ordenado que libere recursos y termine conexiones.

**Prácticas recomendadas.** Manejo de **SIGTERM**/**SIGINT**, *preStop hooks*, `readinessProbe`/`startupProbe` en K8s, *rolling updates* y *canary*.

**Ejemplo DevOps.** Despliegues que reemplazan pods gradualmente, recuperación ante fallos sin intervención manual.

**Enfoque DevSecOps.** Aplicar parches de seguridad de forma ágil, minimizar ventanas de exposición durante *rollouts*, y asegurar que el *drain* no deja procesos "colgados" con datos sensibles.


#### 10) Dev/Prod Parity = Paridad entre entornos

**Concepto.** Mantener **mínimas diferencias** entre Dev, Staging y Prod: la misma imagen, solo cambian valores de configuración/inventario.

**Prácticas recomendadas.** Promover un artefacto único entre ambientes, controlar *drift* con **IaC**, pruebas de humo y contratos por ambiente.

**Ejemplo DevOps.** Helm/Terraform gestionan diferencias, *feature flags* coordinan la activación de capacidades.

**Enfoque DevSecOps.** Escaneos y *policies* uniformes, *tfsec* y OPA para impedir configuraciones inseguras, auditoría de cambios de infraestructura y *drift detection*.

#### 11) Logs = Flujos de eventos

**Concepto.** La app escribe logs en **STDOUT/STDERR**, la plataforma los recolecta y enruta.

**Prácticas recomendadas.** Formato **JSON**, correlación con *trace-id*, *central logging* (EFK/ELK, CloudWatch, OpenTelemetry Collector), retención y búsqueda.

**Ejemplo DevOps.** Dashboards de Kibana/Loki, alertas por patrones, *trace sampling* para diagnóstico.

**Enfoque DevSecOps.** Protección contra manipulación, resguardo de **PII** y *compliance*, detecciones de comportamiento anómalo, alertas de seguridad y conservación para *forensics*.


#### 12) Admin Processes = Tareas puntuales

**Concepto.** Procesos administrativos (migraciones de DB, *seeding*, *housekeeping*) se ejecutan como **Jobs/CronJobs** o etapas del pipeline, no dentro del *web process*.

**Prácticas recomendadas.** Mantener el mismo *runtime* y configuración que la app, diseñar para ejecución aislada y repetible, *idempotencia*.

**Ejemplo DevOps.** Jobs en Kubernetes o pasos en CI para migraciones, *rollback* planificado si falla una migración.

**Enfoque DevSecOps.** **RBAC** estricto, mínimos privilegios, auditoría detallada, mecanismos *break-glass* controlados con expiración, escaneo de imágenes de *jobs* y firma de artefactos igual que en *build* de la app.

#### Integración transversal con DevSecOps

Los 12 factores proporcionan enlaces claros para controles de seguridad integrados "desde el diseño":

* **Gobierno del repositorio (1).** *Branch protection*, firmas y revisiones obligatorias, **SAST** y *secret scanning* automáticos.
* **Cadena de dependencias (2).** **SCA** + **SBOM**, bloqueo de *builds* ante CVEs, vigilancia de *supply chain*.
* **Gestión de configuración (3).** *Secret managers*, cifrado, **OPA/Conftest** para exigir buenas prácticas, rotación y revocación.
* **Servicios adjuntos (4).** TLS/mTLS, credenciales de menor privilegio, *network policies*, *service mesh* cuando proceda.
* **Separación de etapas (5).** Firma (**cosign**), *attestations* de **provenance** y metas **SLSA**, *gates* de seguridad antes de promover *releases*, **DAST** en *staging*.
* **Stateless + escalabilidad (6-8).** Facilita *blue-green/canary* y parches rápidos, *rate limiting* y *circuit breaking* como barreras de seguridad.
* **Disposability (9).** Ventanas cortas en *rollouts*, menor exposición a vulnerabilidades conocidas, *graceful shutdown* que evita pérdidas de datos.
* **Paridad (10).** Controles homogéneos, reproducibilidad y *drift control* con IaC, auditoría centralizada.
* **Observabilidad (11).** *Security analytics*, detección temprana y trazabilidad de incidentes, retención y etiquetado de datos sensibles.
* **Tareas administrativas (12).** *Jobs* con permisos mínimos, logs y métricas, evidencias y auditoría completa.

#### Aterrizaje operativo en pipelines, contenedores y Kubernetes

**Pipelines CI/CD.** Cada repositorio de servicio integra etapas **build -> release -> run**. En *build*: creación de imagen con dependencias declaradas y *lockfiles*, generación de **SBOM**, ejecución de **SAST/SCA**, pruebas unitarias y estáticas. 
En *release*: etiquetado semántico, firma de imagen, *attestations* de *provenance*, plantillas de *manifests* (Helm/Kustomize). 
En *run*: despliegue progresivo, *health checks*, HPA y *rollbacks* automatizados. Se monitorea estado con métricas y trazas, los *quality gates* de seguridad deben aprobarse para promover.

**Contenedores.** La imagen concreta los factores 2 (dependencias) y 5 (build). Se aplican prácticas de endurecimiento: base mínima, *non-root*, *read-only filesystem*, *capabilities* reducidas y escaneo de vulnerabilidades. 
Dependencias quedan auditables dentro de la imagen, su firma permite *admission control* en el clúster.

**Kubernetes.** Los factores 6-9 se operacionalizan con **Deployments** (stateless), **Services/Ingress** (port binding y ruteo), **HPA** (concurrency), *rollouts* y *graceful termination*. Para el 3 (config), se emplean **ConfigMaps/Secrets**, para el 12 (admin), **Jobs/CronJobs**. Con DevSecOps, se añaden **NetworkPolicies**, *Pod Security Standards*, *imagePolicyWebhook* o *admission controllers* que verifiquen firma y cumplimiento de políticas (por ejemplo, OPA Gatekeeper). 
La **paridad** (10) se garantiza promoviendo la misma imagen entre ambientes y versionando IaC para infraestructura idéntica con valores distintos.

**Observabilidad y auditoría.** El 11 se traduce en *logging* centralizado y trazas distribuidas (OpenTelemetry), con etiquetas de *trace-id* correlacionadas. Se definen SLO/SLI y *error budgets*, alimentando *dashboards* y alertas. 
En DevSecOps, los logs alimentan analítica de seguridad, detección de anomalías y forense posterior a incidentes.

**Evidencias y control de calidad.** Cada principio debe producir artefactos verificables: manifiestos, *Dockerfiles*, archivos de dependencias, definiciones de *secrets/configs*, *pipelines YAML*, reportes SAST/SCA/DAST, SBOM, firmas y *attestations*. 
Las *reviews* verifican que las prácticas 12-Factor se reflejen en el diseño, que los secretos no estén en el código, que los endpoints de *backing services* se parametrizan, que exista *health checking* y que *readiness/startup* estén bien definidos para *rollouts* seguros.

**Gestión del cambio y riesgo.** Con los 12 factores, el "*blast radius*" de un despliegue disminuye: los cambios se encapsulan en una imagen firmada con dependencias auditadas, la configuración  vive fuera del binario, los servicios *stateless* permiten reemplazar instancias rápidamente, la paridad de entornos reduce sorpresas y la observabilidad da señales tempranas. 
DevSecOps añade *gates* antes de promover y controles en tiempo de admisión y ejecución, de forma que desarrollo, operaciones y seguridad comparten un mismo flujo de evidencias.

**Síntesis operacional.** Los **12-Factor App Principles** organizan la arquitectura y operación de cada servicio, **DevSecOps** asegura que cada decisión tenga controles verificables de seguridad y cumplimiento. 
Adoptados en conjunto, ofrecen un marco práctico para construir, publicar y operar software con calidad de producción, minimizando deuda técnica, facilitando escalabilidad y 
manteniendo la trazabilidad y la integridad de la cadena de suministro de extremo a extremo.
