Source repo for Putz/Tetazoo MIT Mystery Hunt team. YMMV.

When you checkout a clean copy, you need to do (at least) the following
before things will work:

1. cp puzzlebitch/lib/PB/Config.pm-template puzzlebitch/lib/PB/Config.pm

2. edit puzzlebitch/lib/PB/Config.pm
 * Domain name
 * admin password

3. Set the PERL5LIB environment variable before running scripts in admin-tools:
 * export PERL5LIB=[INSTALL_DIR]/puzzlebitch/lib:${PERL5LIB}

4. If you want to install in a dev environment alongside the deployed version, 
   clone/copy into a directory starting with "puzzlebitch-" (such as 
   "puzzlebitch-dev" in the same parent dir as the "puzzlebitch" directory)

5. If you are working in a "dev" version, set PERL5LIB accordingly and also 
   set the PB_DEV_VERSION environment variable to the string that comes after 
   puzzlebitch in the dev version.
 * export PB_DEV_VERSION="-dev"

6. Run the following admin-tools:
 * ./admin-tools/init-db.sh  (initializes the mysql database)
 * ./admin-tools/install-apache-conf.sh (sets up an apache config in ./apache-conf/sites/canadia-apache.conf)
 * ./admin-tools/add_all_ldap_users_as_solvers.pl (adds all users in LDAP to the PB database)

7. Link the apache config in ./apache-conf/sites/canadia-apache.conf in to the apache2 sites-enabled conf dir, 
   and restart apache (currently support apache 2.2).

