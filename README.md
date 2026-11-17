# BitsailorImage


### Manually install:
* sbcl
* mapnik/shptree
* sendmail

* api-key

### Static datasets and deployment (Fedora 44+)

The Bitsailor checkout under `deps/bitsailor` must include its dataset Makefile.
Build the core with the desired dependency revisions before deploying it; install
and update deliberately do not pull a newer checkout independently of the core.
`make install`, `make update`, and `make webfiles` first call
`make -C deps/bitsailor all`. This downloads/caches EMODnet E4 and generates
missing or outdated Channel LAT tiles. Future datasets added to Bitsailor's
`all` target will also be prepared. Required dataset tools are `make`, `curl`,
`unzip`, `python3`, `python3-numpy`, and `netcdf`; no software is installed by
this preparation step.

The whole prepared `web/` tree, including `bathymetry/channel-2024/`, is copied
to `/etc/bitsailor/web/`. Source archives and the `local/` build cache remain
in the checkout. `make web-assets` prepares datasets without deploying them.
Preparation errors stop deployment before web files are copied or the service
is restarted.

On install and update, existing `bitsailor.conf`, `server-config.cl`, and the
systemd `bitsailor.service` are **never overwritten**. Defaults are copied only
when absent, including polars and optional race files. New web assets and the
core replace their deployed versions; destination-only web files remain.
Review new configuration defaults manually when upgrading, especially HTTP
endpoint registrations in `server-config.cl`. Install reloads systemd; update
reloads systemd and restarts Bitsailor after successful copying. `webfiles`
does neither.

For staging or verification without touching the running service:

```sh
make install DESTDIR=/tmp/bitsailor-stage
make update DESTDIR=/tmp/bitsailor-stage
```

A nonempty `DESTDIR` prefixes deployment paths and skips all systemctl calls.
It does not rewrite absolute paths inside configuration defaults or the core.
`BITSAILOR_DIR` can select another matching checkout. Deployment destinations
can be overridden with `BINDIR`, `CONFDIR`, `WEBROOT`, `DATADIR`, `LOGDIR`, and
`SYSTEMD_UNIT_DIR`; these likewise do not rewrite configuration contents.

Run `python3 tests/deployment-tests.py` to verify tile preparation/copying,
configuration preservation and service-control ordering using disposable
directories and a stub systemctl. The tests never call the host's systemctl.

### Runtime selection and existing services

`make-executable.cl` saves `bitsailor.core` with `:executable t`, embedding the
matching SBCL runtime. The service must execute this file directly. Loading it
with a separately installed `sbcl --core` can fail with “core was built for
runtime ... but this is ...”, even if the two SBCL installations report the
same version. `SBCL` selects the builder (for example,
`make BUILD SBCL=/usr/bin/sbcl`); the installed executable carries that runtime.
Updates copy the executable to a temporary file and rename it into place,
avoiding in-place writes to a running executable, and set its mode to 0755.

Existing service definitions are preserved during deployment. To migrate one
that invokes `/usr/local/bin/sbcl --core`, run `sudo systemctl edit bitsailor`
on the deployment host and add:

```ini
[Service]
ExecStart=
ExecStart=/usr/local/bitsailor/bitsailor.core --dynamic-space-size 6144 --lose-on-corruption --disable-ldb
```

Keep any additional site-specific runtime options. Then apply the change:

```sh
sudo systemctl daemon-reload
sudo systemctl restart bitsailor
sudo systemctl status bitsailor
```

No core rebuild is needed to resolve this mismatch when the deployed file was
already saved as an executable. Other shared-library or application startup
errors, if any, are separate from the SBCL runtime identity check.
Run `python3 tests/runtime-tests.py` to check direct standalone startup with
the service's runtime options using a disposable minimal SBCL executable.

### Fedora 42 Workstation setup

$ sudo firewall-cmd --permanent --add-service http 
$ sudo firewall-cmd --permanent --add-service https
$ sudo setsebool httpd_can_network_connect on -P
$ sudo certbot -v --nginx


