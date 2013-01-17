#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

username=$1

if [[ -n "${username}" ]]; then
    dn=`ldapsearch -xLLL -b "${REGISTER_LDAP_DC}" uid=${username} dn | perl -pi -e 's/dn:\ //'`
    if [[ -n "${dn}" ]]; then
	echo "have dn ${dn}, resetting password."
	newpass=`ldappasswd -D "cn=${REGISTER_LDAP_ADMIN_USER},${REGISTER_LDAP_DC}" -x -w "${REGISTER_LDAP_ADMIN_PASS}" "${dn}" | perl -pi -e 's/^.*?:[[:space:]]+//'`
	if [[ -n "${newpass}" ]]; then
	    echo "changed LDAP password to: ${newpass}"
	    echo "attempting to change google apps password (for GTalk with external clients?)"
	    (cd ${PB_GOOGLE_PATH} && ./ChangeUserPass.sh --adminuser "${GOOGLE_ADMIN_USER}" --adminpass "${GOOGLE_ADMIN_PASS}" --domain "${GOOGLE_DOMAIN}" --username "${username}" --password "${newpass}" )
	else
	    echo "could not change ldap password"
	    exit 3
	fi
    else 
	echo "could not find dn for uid ${username}"
	exit 2
    fi
else
    echo "please specify username"
    exit 1
fi
