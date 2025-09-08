# Makefile — Sección 1 (CLI y Automatización)
# Uso:
#   make help      -> Muestra ayuda
#   make tools     -> Verifica herramientas requeridas
#   make report    -> Genera reports/{http.txt,dns.txt,tls.txt,sockets.txt}
#   make all       -> tools + report (idempotente)
#   make clean     -> Borra reports/*.txt

SHELL := /usr/bin/bash
.ONESHELL:
.SILENT:

SCRIPT := scripts/syscheck.sh
REPORTS_DIR := reports
TOOLS := git bash make python3 pytest curl dig ss jq

.PHONY: help tools report all clean

help: ## Muestra esta ayuda
	awk 'BEGIN{FS":.*##"; printf "Targets disponibles:\n"} /^[a-zA-Z0-9_\-]+:.*##/{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

tools: ## Verifica herramientas requeridas
	ok=1; \
	for t in $(TOOLS); do \
		if command -v $$t >/dev/null 2>&1; then \
			printf "[OK] %s\n" $$t; \
		else \
			printf "[FALTA] %s (instálalo y vuelve a correr make)\n" $$t; \
			ok=0; \
		fi; \
	done; \
	[ $$ok -eq 1 ] || { echo "Error: faltan herramientas."; exit 1; }

report: ## Genera los archivos en reports/
	mkdir -p $(REPORTS_DIR)
	chmod +x $(SCRIPT)
	$(SCRIPT)

all: ## Ejecuta tools y luego report
	$(MAKE) tools
	$(MAKE) report
	echo "Listo: revisa $(REPORTS_DIR)/"

clean: ## Borra evidencias generadas
	rm -f $(REPORTS_DIR)/http.txt $(REPORTS_DIR)/dns.txt $(REPORTS_DIR)/tls.txt $(REPORTS_DIR)/sockets.txt || true
