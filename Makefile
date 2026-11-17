################################################################################
## ALTERNATIVE makefile to Docker build


.PHONY: BUILD install update webfiles web-assets deploy-web deploy-files remove clean \
        docker-build-base docker-build docker-run

MKDIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SBCL = `which sbcl`
DEPDIR = deps/
REPOS = makros.git log2.git zlib.git rdparse.git JSGrib.git cl-geomath.git cl-map.git cl-weather.git cl-eccodes.git cl-mbedtls.git PolarCL.git cl-rdbms.git bitsailor.git
QUICKLISP = $(DEPDIR)quicklisp/quicklisp.lisp
LAND_POLYGONS = land-polygons-split-4326
COASTLINES = coastlines-split-4326

IMAGE = bitsailor.core

# The deployment checkout must match the core being installed. Do not pull a
# newer web checkout implicitly during installation of an already built core.
BITSAILOR_DIR ?= $(DEPDIR)bitsailor
DESTDIR ?=
BINDIR ?= /usr/local/bitsailor
CONFDIR ?= /etc/bitsailor
WEBROOT ?= $(CONFDIR)/web
DATADIR ?= /srv/bitsailor
LOGDIR ?= /var/log/bitsailor
SYSTEMD_UNIT_DIR ?= /etc/systemd/system
SYSTEMCTL ?= systemctl

export CL_SOURCE_REGISTRY=$(realpath $(DEPDIR))


BUILD: $(COASTLINES)/lines.qix $(LAND_POLYGONS)/land_polygons.qix $(IMAGE)
	echo 'done'

$(IMAGE): $(QUICKLISP) $(REPOS)
	CL_SOURCE_REGISTRY=$(realpath $(DEPDIR))//; \
	echo $(CL_SOURCE_REGISTRY); \
	$(SBCL) --script make-executable.cl

$(QUICKLISP):
	mkdir -p $(DEPDIR)quicklisp
	cd $(DEPDIR)quicklisp; wget https://beta.quicklisp.org/quicklisp.lisp

cl-mbedtls.git:
	mkdir -p $(DEPDIR); \
	if [ -d  $(DEPDIR)cl-mbedtls ]; then \
		cd $(DEPDIR)cl-mbedtls; git pull; \
	else \
		cd $(DEPDIR); git clone https://github.com/mak08/cl-mbedtls.git; \
	fi; \
	cd  $(MKDIR)/$(DEPDIR)cl-mbedtls; make;

PolarCL.git:
	mkdir -p $(DEPDIR); \
	if [ -d $(DEPDIR)PolarCL ]; then \
		cd $(DEPDIR)PolarCL; git pull; \
	else \
		cd $(DEPDIR); git clone https://github.com/mak08/PolarCL.git; \
	fi; \
	cd  $(MKDIR)/$(DEPDIR)PolarCL; make;

bitsailor.git:
	mkdir -p $(DEPDIR); \
	if [ -d $(DEPDIR)bitsailor ]; then \
		cd $(DEPDIR)bitsailor; git pull; \
	else \
		cd $(DEPDIR); git clone https://github.com/mak08/bitsailor.git; \
	fi;
	if [ -L	 $(DEPDIR)bitsailor/web/js/JSGrib ]; then \
		echo "JSGrib/ exists" ; \
	else \
		cd $(DEPDIR)bitsailor; ln -s ../../../JSGrib ./web/js/JSGrib; \
	fi;

%.git:

	mkdir -p $(DEPDIR); \
	if [ -d $(DEPDIR)$* ]; then \
		cd $(DEPDIR)$*; git pull; \
	else \
		cd $(DEPDIR); git clone https://github.com/mak08/$@; \
	fi;

$(LAND_POLYGONS)/land_polygons.qix: $(LAND_POLYGONS)
	cd land-polygons-split-4326; shptree land_polygons.shp

$(LAND_POLYGONS): $(LAND_POLYGONS).zip
	unzip land-polygons-split-4326.zip

$(LAND_POLYGONS).zip:
	wget https://osmdata.openstreetmap.de/download/land-polygons-split-4326.zip

$(COASTLINES)/lines.qix: $(COASTLINES)
	cd coastlines-split-4326; shptree lines.shp

$(COASTLINES): $(COASTLINES).zip
	unzip coastlines-split-4326.zip

$(COASTLINES).zip:
	wget https://osmdata.openstreetmap.de/download/coastlines-split-4326.zip

# The Bitsailor Makefile downloads/caches EMODnet and generates missing or
# outdated depth tiles. Use its all target so future static datasets join here.
web-assets:
	@test -f "$(BITSAILOR_DIR)/Makefile" || { \
	  echo "Missing $(BITSAILOR_DIR)/Makefile; build with an up-to-date Bitsailor checkout first." >&2; exit 1; }
	$(MAKE) -C "$(BITSAILOR_DIR)" all

# Copy only web assets, including web/bathymetry, never the checkout's configs
# or its local source-data cache. Retain files unique to the deployed web tree.
deploy-web: web-assets
	mkdir -p "$(DESTDIR)$(WEBROOT)"
	cp -R "$(BITSAILOR_DIR)/web/." "$(DESTDIR)$(WEBROOT)/"

# Seed defaults without replacing files edited in the target installation.
# GNU cp --update=none skips existing files successfully (unlike none-fail).
deploy-files: deploy-web
	mkdir -p "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(LOGDIR)" \
	  "$(DESTDIR)$(CONFDIR)/polars" "$(DESTDIR)$(DATADIR)/map" \
	  "$(DESTDIR)$(DATADIR)/weather/noaa" "$(DESTDIR)$(SYSTEMD_UNIT_DIR)"
	cp "$(IMAGE)" "$(DESTDIR)$(BINDIR)/bitsailor.core"
	@for file in bitsailor.conf server-config.cl; do \
	  target="$(DESTDIR)$(CONFDIR)/$$file"; \
	  if [ ! -e "$$target" ] && [ ! -L "$$target" ]; then \
	    cp --update=none "$$file" "$$target" || exit $$?; \
	  fi; \
	done
	@if [ ! -e "$(DESTDIR)$(SYSTEMD_UNIT_DIR)/bitsailor.service" ] \
	    && [ ! -L "$(DESTDIR)$(SYSTEMD_UNIT_DIR)/bitsailor.service" ]; then \
	  cp --update=none bitsailor.service "$(DESTDIR)$(SYSTEMD_UNIT_DIR)/bitsailor.service"; \
	fi
	cp -R --update=none polars/. "$(DESTDIR)$(CONFDIR)/polars/"
	@if [ -d races ]; then \
	  mkdir -p "$(DESTDIR)$(CONFDIR)/races"; \
	  cp -R --update=none races/. "$(DESTDIR)$(CONFDIR)/races/"; \
	fi

install: deploy-files
	cp -R "$(LAND_POLYGONS)" "$(DESTDIR)$(DATADIR)/map/"
	cp -R "$(COASTLINES)" "$(DESTDIR)$(DATADIR)/map/"
	@if [ -z "$(DESTDIR)" ]; then "$(SYSTEMCTL)" daemon-reload; fi
	@echo "Installed. Existing configuration, service definition and custom polars/races were preserved."

update: deploy-files
	@if [ -z "$(DESTDIR)" ]; then \
	  "$(SYSTEMCTL)" daemon-reload && "$(SYSTEMCTL)" restart bitsailor; \
	fi
	@echo "Updated. Existing configuration, service definition and custom polars/races were preserved."

webfiles: deploy-web
	@echo "Web assets and static datasets updated; configuration files were left untouched."

remove:
	rm -rf /etc/bitsailor
	rm -rf /srv/bitsailor

clean:
	-rm -rf deps
	-rm bitsailor.core
	-rm -rf land-polygons-split-4326
	-rm land-polygons-split-4326.zip

docker-build-base:
	docker build --file Dockerfile_base -t bitsailor_base .

docker-build:
	docker build --no-cache --progress=plain -t bitsailor .

docker-run:
	docker run -it --entrypoint /bin/bash bitsailor
