;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Description
;;; Author         Michael Kappert 2021
;;; Last Modified <michael 2026-02-12 20:27:59>

(declaim (optimize (speed 3) (debug 1) (space 1) (safety 1)))

(require "asdf")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Quicklisp
(ignore-errors
  (load "deps/quicklisp/quicklisp.lisp"))
(ignore-errors
  (quicklisp-quickstart:install :path "deps/quicklisp/"))
(ignore-errors
  (quicklisp-quickstart:install))
(ignore-errors
  (load "deps/quicklisp/setup.lisp"))

(ql:quickload "cl-utilities")
(ql:quickload "bordeaux-threads")
(ql:quickload "parse-float")
(ql:quickload "cffi")
(ql:quickload "cl-base64")
(ql:quickload "local-time")
(ql:quickload "usocket")
(ql:quickload "puri")
(ql:quickload "cl-ppcre")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Load bitsailor & save image

(asdf:load-system "bitsailor" :force t)
(asdf:load-system "bitsailor" :force t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Customization (.vhrc aka .bitsailor aka bitsailor.conf)
;;; CL-MAP
(setf cl-map:*map-file* "/srv/bitsailor/map/land-polygons-split-4326/land_polygons.shp")
(setf router:*use-bitmap* nil)
;; (setf cl-map:*bitmap-latpoints* 10800)
;; (setf cl-map:*bitmap-lonpoints* 21600)
;; (setf cl-map:*bitmap-file* "/srv/bitsailor/map/bm-tiled-10800.dat")

;;; CL-WEATHER
(setf cl-weather:*grib-directory* "/srv/bitsailor/weather/current/")
(setf cl-weather:*use-range-query* t)

;;; Router
(setf router:*api-key* (sb-ext:posix-getenv "BITSAILOR_API_KEY"))

(setf router:*db* "/etc/bitsailor/main.sdb")

(setf router:*polars-dir* "/etc/bitsailor/polars/")

(setf router:*rcfile* "/etc/bitsailor/bitsailor.conf")

(setf router:*tracks* t)
(setf router:*twa-steps* 5d0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Create image

(sb-ext:save-lisp-and-die "bitsailor.core" :toplevel #'router:start-router :executable t) 

(sb-ext:quit)

;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
