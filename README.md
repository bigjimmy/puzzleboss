Source repo for Putz/Tetazoo MIT Mystery Hunt team. YMMV.

When you checkout a clean copy, you need to do (at least) the following
before things will work:

1. cp puzzleboss/lib/PB/Config.pm-template puzzleboss/lib/PB/Config.pm

2. edit (at least the top section) of puzzleboss/lib/PB/Config.pm to set:
 * hunt title 
 * username
 * password
 * domain name
 * team name
 * install path (or just install in /canadia/puzzleboss)

3. Set the PERL5LIB environment variable before running scripts in admin-tools:
 * export PERL5LIB=[INSTALL_DIR]/puzzleboss/lib:${PERL5LIB}

4. Run the following admin-tools:
 * ./admin-tools/init-db.sh  (initializes the mysql database)
 * ./admin-tools/add_all_ldap_users_as_solvers.pl (adds all users in LDAP to the PB database)

5. Edit, and then link the apache config in ./apache-conf/sites/canadia-apache.conf in to the apache2 sites-enabled conf dir, 
   and restart apache (currently support apache 2.2).

6. Install the bigjimmy bot init script (and start it)
 * Copy from ./bigjimmy/init-script/bigjimmy 

7. Get meteor server working:
 * How? (FIXME) What config?
 * Configure meteor server info in Config.pm
 
8. Install the discord bot into /canadia/puzzcord.
 * Use systemd startup unit in admin-tools if needed.

---

If you change Config.pm after initializing the database, you need to load that data into the database:
 * ./admin-tools/set-db-config.sh (copies some data from Config.pm into database)
