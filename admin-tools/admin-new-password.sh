#!/bin/bash

username=$1

admin_pass=`cat pw`
domain=`cat domain`
ldapdc=`cat ldapdc`

if [[ -n "${username}" ]]; then
    dn=`ldapsearch -xLLL -b "${ldapdc}" uid=${username} dn | perl -pi -e 's/dn:\ //'`
    if [[ -n "${dn}" ]]; then
	echo "have dn ${dn}, resetting password."
	newpass=`ldappasswd -D "cn=admin,dc=stormynight,dc=org" -x -w "${admin_pass}" "${dn}" | perl -pi -e 's/^.*?:[[:space:]]+//'`
	if [[ -n "${newpass}" ]]; then
	    echo "changed LDAP password to: ${newpass}"
	    echo "attempting to change google apps password (for GTalk with external clients?)"
	    (cd /canadia/puzzlebitch/google && ./ChangeUserPass.sh --domain "${domain}" --username "${username}" --password "${newpass}" )
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
