SHELL := /bin/bash

DOCS_DIR := docs
PORT ?= 9092
HOST ?= 0.0.0.0
PID_FILE := $(DOCS_DIR)/.quarto-preview.pid
LOG_FILE := $(DOCS_DIR)/.quarto-preview.log

.PHONY: help preview stop-preview restart-preview preview-status preview-log render check clean

help:
	@echo "Quarto commands"
	@echo "  make preview PORT=9092        Start preview server in background"
	@echo "  make stop-preview             Stop preview server"
	@echo "  make restart-preview PORT=9092 Restart preview server"
	@echo "  make preview-status           Show preview server status"
	@echo "  make preview-log              Tail preview log"
	@echo "  make render                   Render the book"
	@echo "  make check                    Run 'quarto check'"
	@echo "  make clean                    Remove generated output and preview state"

define port_pid
$$(lsof -tiTCP:$(PORT) -sTCP:LISTEN 2>/dev/null | head -n 1)
endef

preview:
	@if [[ -f "$(PID_FILE)" ]] && kill -0 "$$(cat "$(PID_FILE)")" 2>/dev/null; then \
		echo "Preview server already running on PID $$(cat "$(PID_FILE)")"; \
		echo "If you want a new port, run: make restart-preview PORT=$(PORT)"; \
		exit 0; \
	fi
	@if [[ -n "$(call port_pid)" ]]; then \
		echo "Port $(PORT) is already in use by PID $(call port_pid)"; \
		echo "Run: make stop-preview PORT=$(PORT) or make restart-preview PORT=$(PORT)"; \
		exit 1; \
	fi
	@cd "$(DOCS_DIR)" && nohup quarto preview --no-browser --host "$(HOST)" --port "$(PORT)" > .quarto-preview.log 2>&1 &
	@sleep 3
	@if [[ -n "$(call port_pid)" ]]; then \
		echo "$(call port_pid)" > "$(PID_FILE)"; \
		echo "Preview started: http://localhost:$(PORT)/"; \
		echo "PID: $$(cat "$(PID_FILE)")"; \
		echo "Log: $(LOG_FILE)"; \
	else \
		echo "Failed to start preview server. Check $(LOG_FILE)"; \
		exit 1; \
	fi

stop-preview:
	@if [[ -f "$(PID_FILE)" ]]; then \
		PID="$$(cat "$(PID_FILE)")"; \
		if kill -0 "$$PID" 2>/dev/null; then \
			kill "$$PID"; \
			echo "Stopped preview server PID $$PID"; \
		else \
			echo "Preview PID file exists but process $$PID is not running"; \
		fi; \
		rm -f "$(PID_FILE)"; \
	else \
		echo "No preview PID file found"; \
	fi
	@if [[ -n "$(call port_pid)" ]]; then \
		PORT_PID="$(call port_pid)"; \
		kill "$$PORT_PID" 2>/dev/null || true; \
		echo "Stopped process on port $(PORT): PID $$PORT_PID"; \
	fi

restart-preview: stop-preview preview

preview-status:
	@if [[ -f "$(PID_FILE)" ]]; then \
		PID="$$(cat "$(PID_FILE)")"; \
		if kill -0 "$$PID" 2>/dev/null; then \
			echo "Preview server is running"; \
			echo "PID: $$PID"; \
			echo "Log: $(LOG_FILE)"; \
			echo "URL: http://localhost:$(PORT)/"; \
		else \
			echo "Preview PID file exists but process $$PID is not running"; \
			exit 1; \
		fi; \
	elif [[ -n "$(call port_pid)" ]]; then \
		echo "Preview-related process is running on port $(PORT)"; \
		echo "PID: $(call port_pid)"; \
		echo "URL: http://localhost:$(PORT)/"; \
	else \
		echo "Preview server is not running"; \
		exit 1; \
	fi

preview-log:
	@if [[ -f "$(LOG_FILE)" ]]; then \
		tail -n 50 -f "$(LOG_FILE)"; \
	else \
		echo "No preview log found at $(LOG_FILE)"; \
		exit 1; \
	fi

render:
	@cd "$(DOCS_DIR)" && quarto render

check:
	@cd "$(DOCS_DIR)" && quarto check

clean: stop-preview
	@rm -rf "$(DOCS_DIR)/_book"
	@rm -f "$(PID_FILE)" "$(LOG_FILE)"
	@echo "Cleaned generated output and preview state"