#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

# install canadia-apache.conf from template 
# you should also run ln -s $PB_PATH/apache-conf/sites/canadia-apache.conf /etc/apache/sites-enabled/ 
# and then restart the web server
cat ${PB_PATH}/apache-conf/sites/canadia-apache.conf-template | perl -pi -e 'my $instpath="'${INSTALL_PATH}'"; s/\$DOMAIN_NAME/'${PB_DOMAIN_NAME}'/g; s/\$INSTALL_PATH/$instpath/g; s/\$BIGJIMMY_IP/'${BIGJIMMY_IP}'/g;' > ${PB_PATH}/apache-conf/sites/canadia-apache.conf

# install mod_perl_startup.pl from template (mod_perl_startup.pl is used to set perl lib in mod_perl)
cat ${PB_BIN_PATH}/mod_perl_startup.pl-template | perl -pi -e 'my $pbpath="'${PB_PATH}'"; s/\$PB_PATH/$pbpath/g;' > ${PB_BIN_PATH}/mod_perl_startup.pl

# install pblib.cfg from template (pblib.cfg is used to set perl lib from CGI scripts)
cat ${PB_BIN_PATH}/pblib.cfg-template | perl -pi -e 'my $pbpath="'${PB_PATH}'"; s/\$PB_PATH/$pbpath/g;' > ${PB_BIN_PATH}/pblib.cfg

