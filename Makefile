################################################################################
## ALTERNATIVE makefile to Docker build


.PHONY: BUILD INSTALL

MKDIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

DEPDIR = deps/
REPOS = makros.git log2.git zlib.git rdparse.git cl-geomath.git cl-map.git cl-weather.git cl-eccodes.git cl-mbedtls.git PolarCL.git cl-rdbms.git bitsailor.git
QUICKLISP = $(DEPDIR)quicklisp/quicklisp.lisp
LAND_POLYGONS = land-polygons-split-4326
COASTLINES = coastlines-split-4326

IMAGE = bitsailor.core

export CL_SOURCE_REGISTRY=$(realpath $(DEPDIR))


BUILD: $(COASTLINES)/lines.qix $(LAND_POLYGONS)/land_polygons.qix $(IMAGE)
	echo 'done'

$(IMAGE): $(QUICKLISP) $(REPOS)
	CL_SOURCE_REGISTRY=$(realpath $(DEPDIR))//; \
	echo $(CL_SOURCE_REGISTRY); \
	sbcl --script make-executable.cl

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

install:
	mkdir -p /usr/local/bitsailor
	mkdir -p /var/log/bitsailor
	mkdir -p /etc/bitsailor
	mkdir -p /srv/bitsailor/map
	mkdir -p /srv/bitsailor/weather/current
	mkdir -p /srv/bitsailor/weather/archive
	cp -R $(LAND_POLYGONS) /srv/bitsailor/map/
	cp -R $(COASTLINES) /srv/bitsailor/map/
	cp bitsailor.core /usr/local/bitsailor/
	cp bitsailor.conf /etc/bitsailor/bitsailor.conf
	cp -R $(DEPDIR)bitsailor/web /etc/bitsailor/
	cp server-config.cl /etc/bitsailor/server-config.cl
	cp -R polars /etc/bitsailor/
	cp -R races /etc/bitsailor/
	cp bitsailor.service /etc/systemd/system/
	systemctl daemon-reload

update:
	echo "Copying image..."
	cp bitsailor.core /usr/local/bitsailor/
	echo "Copying webpage..."
	cp -R $(DEPDIR)bitsailor/web /etc/bitsailor/
	echo "Copying service definition..."
	cp bitsailor.service /etc/systemd/system/
	echo "Restarting service..."
	systemctl daemon-reload
	systemctl restart bitsailor
	echo "Done - please adjust config files manually."

webfiles:
	cp -R $(DEPDIR)bitsailor/web /etc/bitsailor/
	echo "Done - please adjust config files manually and restart if necessary."

remove:
	rm -rf /etc/bitsailor
	rm -rf /srv/bitsailor

clean:
	-rm -rf deps
	-rm bitsailor.core
	-rm -rf land-polygons-split-4326
	-rm land-polygons-split-4326.zip
