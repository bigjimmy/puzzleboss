#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

# install canadia-apache.conf from template 
# you should also run ln -s $PB_PATH/apache-conf/sites/canadia-apache.conf /etc/apache/sites-enabled/ 
# and then restart the web server
cat $PB_PATH/apache-conf/sites/canadia-apache.conf-template | perl -pi -e 's/\$DOMAIN_NAME/'$DOMAIN_NAME'/g; s/\$INSTALL_PATH/'$INSTALL_PATH'/g;' > $PB_PATH/apache-conf/sites/canadia-apache.conf

# install mod_perl_startup.pl from template (mod_perl_startup.pl is used to set perl lib in mod_perl)
cat $PB_BIN_PATH/mod_perl_startup.pl-template | perl -pi -e 's/\$PB_PATH/'$PB_PATH'/g;' > $PB_BIN_PATH/mod_perl_startup.pl

# install pblib.cfg from template (pblib.cfg is used to set perl lib from CGI scripts)
cat $PB_BIN_PATH/mod_perl_startup.pl-template | perl -pi -e 's/\$PB_PATH/'$PB_PATH'/g;' > $PB_BIN_PATH/mod_perl_startup.pl

