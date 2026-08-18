PKG_REPO ?= https://github.com/mslxnu/pkg.git
PORTS_REPO ?= https://github.com/freebsd/freebsd-ports.git
PORTS_SPARSE ?= ports-mgmt/pkg ports-mgmt/pkg_cutleaves ports-mgmt/pkgs_which ports-mgmt/pkg_cleanup ports-mgmt/pkg_tree ports-mgmt/pkg-rmleaf
PREFIX ?= /usr/local
DESTDIR ?=
BUILD_DIR ?= _build
PKG_DIR ?= pkg
PORTS_DIR ?= freebsd-ports
CLEAN_REPOS ?= 0

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail

export PREFIX

.PHONY: all pkg utils scripts install clean distclean

all: pkg utils scripts

pkg:
	@if [ ! -d "$(PKG_DIR)" ]; then \
		echo "Cloning $(PKG_REPO) into $(PKG_DIR)..."; \
		git clone --depth=1 "$(PKG_REPO)" "$(PKG_DIR)"; \
	else \
		echo "Using existing $(PKG_DIR)"; \
	fi
	@if [ ! -f "$(PKG_DIR)/Makefile" ]; then \
		echo "Running configure in $(PKG_DIR)..."; \
		cd "$(PKG_DIR)" && ./configure --prefix="$(PREFIX)"; \
	fi
	@echo "Building pkg..."
	@cd "$(PKG_DIR)" && $(MAKE)

$(PORTS_DIR):
	@echo "Cloning $(PORTS_REPO) into $(PORTS_DIR) (sparse checkout of $(PORTS_SPARSE))..."
	@git clone --depth=1 --filter=blob:none --sparse "$(PORTS_REPO)" "$(PORTS_DIR)"
	@cd "$(PORTS_DIR)" && git sparse-checkout set $(PORTS_SPARSE)

utils: $(PORTS_DIR)
	@mkdir -p "$(BUILD_DIR)/bin" "$(BUILD_DIR)/share/man/man1"
	@echo "Applying patches to ports tree..."
	@if [ -f "$(CURDIR)/patches/pkg_cleanup-darwin.patch" ]; then \
		if grep -q 'pkg_pclose = pclose(pkg)' "$(PORTS_DIR)/ports-mgmt/pkg_cleanup/files/pkg_cleanup.c" 2>/dev/null; then \
			echo "Patch pkg_cleanup-darwin already applied, skipping"; \
		else \
			patch -d "$(PORTS_DIR)" -p1 < "$(CURDIR)/patches/pkg_cleanup-darwin.patch"; \
		fi; \
	fi
	@echo "Building pkg utilities from ports tree..."
	@# pkg_cutleaves
	@if [ -f "$(PORTS_DIR)/ports-mgmt/pkg_cutleaves/files/pkg_cutleaves" ]; then \
		cp "$(PORTS_DIR)/ports-mgmt/pkg_cutleaves/files/pkg_cutleaves" "$(BUILD_DIR)/bin/"; \
		cp "$(PORTS_DIR)/ports-mgmt/pkg_cutleaves/files/pkg_cutleaves.1" "$(BUILD_DIR)/share/man/man1/"; \
		chmod +x "$(BUILD_DIR)/bin/pkg_cutleaves"; \
	fi
	@# pkgs_which
	@if [ -f "$(PORTS_DIR)/ports-mgmt/pkgs_which/files/pkgs_which" ]; then \
		cp "$(PORTS_DIR)/ports-mgmt/pkgs_which/files/pkgs_which" "$(BUILD_DIR)/bin/"; \
		chmod +x "$(BUILD_DIR)/bin/pkgs_which"; \
	fi
	@# pkg_cleanup - requires FreeBSD-specific bsddialog/curses
	@if [ -f "$(PORTS_DIR)/ports-mgmt/pkg_cleanup/files/pkg_cleanup.c" ]; then \
		if [ "$$(uname -s)" = "Darwin" ]; then \
			echo "Building pkg_cleanup for macOS..."; \
			CFLAGS_PKG_CLEANUP=""; \
			LDFLAGS_PKG_CLEANUP=""; \
			if pkg-config --exists dialog 2>/dev/null; then \
				CFLAGS_PKG_CLEANUP="$$CFLAGS_PKG_CLEANUP $$(pkg-config --cflags dialog)"; \
				LDFLAGS_PKG_CLEANUP="$$LDFLAGS_PKG_CLEANUP $$(pkg-config --libs dialog)"; \
			elif [ -d /opt/homebrew/opt/dialog/include ] && [ -d /opt/homebrew/opt/dialog/lib ]; then \
				CFLAGS_PKG_CLEANUP="$$CFLAGS_PKG_CLEANUP -I/opt/homebrew/opt/dialog/include"; \
				LDFLAGS_PKG_CLEANUP="$$LDFLAGS_PKG_CLEANUP -L/opt/homebrew/opt/dialog/lib -ldialog"; \
			fi; \
			if pkg-config --exists ncurses 2>/dev/null; then \
				CFLAGS_PKG_CLEANUP="$$CFLAGS_PKG_CLEANUP $$(pkg-config --cflags ncurses)"; \
				LDFLAGS_PKG_CLEANUP="$$LDFLAGS_PKG_CLEANUP $$(pkg-config --libs ncurses)"; \
			elif [ -f /opt/homebrew/opt/ncurses/lib/libncurses.dylib ]; then \
				CFLAGS_PKG_CLEANUP="$$CFLAGS_PKG_CLEANUP -I/opt/homebrew/opt/ncurses/include"; \
				LDFLAGS_PKG_CLEANUP="$$LDFLAGS_PKG_CLEANUP -L/opt/homebrew/opt/ncurses/lib -lncurses"; \
			elif [ -f /usr/local/lib/libncurses.dylib ]; then \
				LDFLAGS_PKG_CLEANUP="$$LDFLAGS_PKG_CLEANUP -lncurses"; \
			fi; \
			cc -O2 $$CFLAGS_PKG_CLEANUP -o "$(BUILD_DIR)/bin/pkg_cleanup" \
				"$(PORTS_DIR)/ports-mgmt/pkg_cleanup/files/pkg_cleanup.c" $$LDFLAGS_PKG_CLEANUP \
				&& chmod +x "$(BUILD_DIR)/bin/pkg_cleanup" \
				|| echo "Warning: pkg_cleanup build failed (missing dialog/ncurses)"; \
			if [ -f "$(PORTS_DIR)/ports-mgmt/pkg_cleanup/files/pkg_cleanup.1" ]; then \
				cp "$(PORTS_DIR)/ports-mgmt/pkg_cleanup/files/pkg_cleanup.1" "$(BUILD_DIR)/share/man/man1/"; \
			fi; \
		fi; \
	fi
	@# pkg-rmleaf
	@if [ -f "$(PORTS_DIR)/ports-mgmt/pkg-rmleaf/files/pkg-rmleaf" ]; then \
		cp "$(PORTS_DIR)/ports-mgmt/pkg-rmleaf/files/pkg-rmleaf" "$(BUILD_DIR)/bin/"; \
		chmod +x "$(BUILD_DIR)/bin/pkg-rmleaf"; \
	fi

scripts:
	@mkdir -p "$(BUILD_DIR)/bin"
	@if [ -f "$(PKG_DIR)/scripts/pkg_tree.sh" ]; then \
		cp "$(PKG_DIR)/scripts/pkg_tree.sh" "$(BUILD_DIR)/bin/pkg_tree"; \
		chmod +x "$(BUILD_DIR)/bin/pkg_tree"; \
	fi
	@if [ -f "$(PKG_DIR)/scripts/sign_pkg.sh" ]; then \
		cp "$(PKG_DIR)/scripts/sign_pkg.sh" "$(BUILD_DIR)/bin/sign_pkg"; \
		chmod +x "$(BUILD_DIR)/bin/sign_pkg"; \
	fi
	@if [ -f "$(PKG_DIR)/scripts/pkg_aspcud.sh" ]; then \
		cp "$(PKG_DIR)/scripts/pkg_aspcud.sh" "$(BUILD_DIR)/bin/pkg_aspcud"; \
		chmod +x "$(BUILD_DIR)/bin/pkg_aspcud"; \
	fi

install: all
	@echo "Installing pkg..."
	@cd "$(PKG_DIR)" && $(MAKE) install DESTDIR="$(DESTDIR)" PREFIX="$(PREFIX)"
	@mkdir -p "$(DESTDIR)$(PREFIX)/bin" "$(DESTDIR)$(PREFIX)/share/man/man1" "$(DESTDIR)$(PREFIX)/share/man/man8"
	@install -m 755 "$(BUILD_DIR)/bin/"* "$(DESTDIR)$(PREFIX)/bin/"
	@install -m 644 "$(BUILD_DIR)/share/man/man1/"* "$(DESTDIR)$(PREFIX)/share/man/man1/" 2>/dev/null || true
	@for m in "$(PKG_DIR)"/docs/pkg-*.8; do \
		install -m 644 "$$m" "$(DESTDIR)$(PREFIX)/share/man/man8/"; \
	done
	@install -m 644 "$(PKG_DIR)"/docs/pkg.8 "$(DESTDIR)$(PREFIX)/share/man/man8/"

clean:
	@if [ -d "$(PKG_DIR)" ]; then \
		cd "$(PKG_DIR)" && $(MAKE) clean 2>/dev/null || true; \
	fi
	@rm -rf "$(BUILD_DIR)"
	@if [ "$(CLEAN_REPOS)" = "1" ]; then \
		if [ -d "$(PKG_DIR)" ]; then rm -rf "$(PKG_DIR)"; fi; \
		if [ -d "$(PORTS_DIR)" ]; then rm -rf "$(PORTS_DIR)"; fi; \
	fi

distclean: clean
	@if [ -d "$(PKG_DIR)" ]; then \
		rm -rf "$(PKG_DIR)"; \
	fi
	@if [ -d "$(PORTS_DIR)" ]; then \
		rm -rf "$(PORTS_DIR)"; \
	fi
