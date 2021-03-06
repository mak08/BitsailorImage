;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Description
;;; Author         Michael Kappert 2016
;;; Last Modified <michael 2022-07-20 22:59:17>

(in-package :router)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Customize log levels

(setf (log2:log-level "virtualhelm:log-stats") log2:+trace+)
(setf (log2:log-level "cl-weather") log2:+info+)
(setf (log2:log-level "cl-weather:noaa-file-complete-p") log2:+trace+)
(setf (log2:log-level "cl-weather:noaa-uris-exist-p") log2:+trace+)

(setf (log2:log-level "polarcl") log2:+info+)
(setf (log2:log-level "mbedtls") log2:+info+)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; -------
;;; Servers
;;; -------

(format t "~a"
        (merge-pathnames (make-pathname :directory '(:relative "web"))
                         (make-pathname :directory (pathname-directory *load-pathname*))))

;;; Start one server on port 8080. 
(server :hostname "0.0.0.0" ;; Hostname binds to the WLAN/LAN interface! 
        :protocol :http
        :mt-method :ondemand
        :port "8080"
        :max-handlers 10)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; -----
;;; Users
;;; -----

(user :username "admin" :realm "bitsailor" :password "_admin_01")
(user :username "admin" :realm "admin" :password "_admin_01")
(user :username "user01" :realm "bitsailor" :password "_user_01")
(user :username "guest" :realm "bitsaialor" :password "_guest_01")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; -----------
;;; Redirection : Every request referring to a directory is mapped to index.html in that directory
;;; -----------

(redirect
 :from (:path "/")
 :to (:path "/start"))

(redirect
 :from (:regex ".*/^")
 :to (:path "index.html"))

(redirect
 :from (:scheme "http" :port ("8088"))
 :to (:scheme "https" :port "443"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; -------------
;;; QUERY-FUNCTION endpoint
;;; -------------

(handle
 :request (:prefix "/function")
 :handler (:query-function t :authentication nil :realm "bitsailor"))

(register-function "router.signUp" :authorizer (constantly t))
(register-function "router.getSession" :authorizer #'vh-function-authorizer)
(register-function "router.removeSession" :authorizer #'vh-function-authorizer)
(register-function "router.getRaceInfo" :authorizer #'vh-function-authorizer)
(register-function "router.getWind" :authorizer #'vh-function-authorizer)
(register-function "router.getTWAPath" :authorizer #'vh-function-authorizer)
(register-function "router.setParameter" :authorizer #'vh-function-authorizer)
(register-function "router.getRaceList" :authorizer (constantly t))
(register-function "router.resetNMEAConnection" :authorizer #'vh-function-authorizer)
(register-function "router.getBoatPosition" :authorizer #'vh-function-authorizer)
(register-function "router.setRoute" :authorizer #'vh-function-authorizer)
(register-function "router.getRoute" :authorizer #'vh-function-authorizer)
(register-function "router.getRouteRS" :authorizer #'vh-function-authorizer)
(register-function "router.checkWindow" :authorizer #'vh-function-authorizer)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ----------------
;;; Static content
;;; ----------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Polars -

(handle
 :request ( :method :get
            :path "/polars")
 :handler ( :directory  "/etc/bitsailor/polars"
            :authentication nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GRIBs

(handle
 :request (:method :get
           :prefix "/weather")
 :handler (:directory "/srv/bitsailor/weather"
           :realm "bitsailor"
           :authorizer #'vh-authorizer))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Web page

(handle
 :request (:prefix "/js")
 :handler (:static (namestring
                    (merge-pathnames (make-pathname :directory '(:relative "web" "js"))
                                     *source-root*))
           :authentication nil))
(handle
 :request (:prefix "/css")
 :handler (:static (namestring
                    (merge-pathnames (make-pathname :directory '(:relative "web" "css"))
                                     *source-root*))
           :authentication nil))

(handle
 :request (:prefix "/img")
 :handler (:static (namestring
                    (merge-pathnames (make-pathname :directory '(:relative "web" "img"))
                                     *source-root*))
           :authentication nil))

(handle
 :request (:prefix "/polars")
 :handler (:static (namestring *polars-dir*)
           :authentication nil))

(handle
 :request (:method :get
           :path "/start")
 :handler (:dynamic 'start-page
           :authentication nil))

(handle
 :request (:method :get
           :path "/router")
 :handler (:dynamic 'router
           :realm "bitsailor"
           :authorizer #'vh-authorizer))
(handle 
 :request (:method :get
           :prefix "/activate-account")
 :handler (:dynamic 'activate-account
           :authentication nil))
;;; We can't match root for now, match length priority is not implemented or does not work...
(handle 
 :request (:prefix "")
 :handler (:static (namestring
                    (merge-pathnames (make-pathname :directory '(:relative "web"))
                                     *source-root*))
           :authentication nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ----------------
;;; Administration
;;; ----------------


;;; A :dynamic handler calls the specified function on the matched request and
;;; and a default "OK" response. Login as 'admin' required.
(handle
 :request (:method :get
           :path "/quit")
 :handler (:dynamic (lambda (server handler request response)
                       (declare (ignore response))
                       (cond
                         ((string= (http-authenticated-user handler request)
                                   "admin")
                          (stop-all-servers)
                          (setf *run* nil)
                          (values
                           "<!DOCTYPE html><html><body><b><em>Goodby</em></b></body><html>"))
                         (t
                          (values
                           "<!DOCTYPE html><html><body><b><em>Not authorized.</em></b></body><html>"))))
                    :realm "admin"))

;;; EOF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
