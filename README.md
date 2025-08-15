# BitsailorImage


### Manually install:
* sbcl
* mapnik/shptree
* sendmail

* api-key

### Fedora 42 Workstation setup

$ sudo firewall-cmd --permanent --add-service http 
$ sudo firewall-cmd --permanent --add-service https
$ sudo setsebool httpd_can_network_connect on -P
$ sudo certbot -v --nginx


