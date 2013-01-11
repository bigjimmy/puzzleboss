#!/bin/bash

username=$1

admin_pass=`cat pw`
domain=`cat domain`
ldapdc=`cat ldapdc`

if [[ -n "${username}" ]]; then
    ldif=`ldapsearch -x -D cn=admin,dc=stormynight,dc=org -w ${admin_pass} -LLL -b "dc=${ldapdc}" uid=${username} uid sn givenName userPassword`
    if [[ -n "${ldif}" ]]; then
	echo "ldif:${ldif}"
	googleargs0=`echo "${ldif}" | awk 'BEGIN {FS=": ";} {map[$1]=$2;} END {print "--username \""map["givenName"]map["sn"]"\" --firstname \""map["givenName"]"\" --lastname \""map["sn"]"\"\t"map["userPassword:"]"";}'`

	googleargs=`echo "${googleargs0}" | cut -f1 -d"	"`
	password64=`echo "${googleargs0}" | cut -f2 -d"	"`'='
	echo "have password64: ${password64}"
	password16=`echo "${password64}" | perl -pi -e 'use MIME::Base64 qw(decode_base64); use MIME::Base16; $_=MIME::Base16::encode(decode_base64($_));'`
	echo "have password16: ${password16}"
	if [[ -n "${googleargs}" && -n "${password16}" ]]; then
	    echo "creating google user with args: ${googleargs} --passwordhash ${password16}"
	    # TODO path and domain should come from config
	    (cd /canadia/puzzlebitch/google && ./AddDomainUser.sh --domain "${domain}"  ${googleargs} --passwordhash "${password16}")
	else
	    echo "could not change ldap password"
	    exit 3
	fi
    else 
	echo "could not find ldap entry for uid ${username}"
	exit 2
    fi
else
    echo "please specify username"
    exit 1
fi
