#!/bin/bash

admin_pass=`cat pw`
domain=`cat domain`
ldapdc=`cat ldapdc`

deleteuser=`echo $1 | perl -pi -e 's/[[:space:]*]//g'`


if [ -z "$deleteuser" ]; then
    echo "please specify user to delete"
else

    echo "deleting user $deleteuser"
    deletedn=`ldapsearch -xLLL -b "${ldapdc}" uid=$deleteuser dn|cut -d':' -f2|head -n 1|perl -pi -e 's/[[:space:]*]//g'`
    if [ -z "$deletedn" ]; then
	echo "ldap user does not exist"
    else 
	echo "deleting ldap dn $deletedn"
	ldapdelete -x -D cn=admin,${ldapdc} -w ${admin_pass} $deletedn
    fi


    echo "deleting google user $deleteuser"
    (cd /canadia/puzzlebitch/google && ./DeleteDomainUser.sh -u $deleteuser -d ${domain})


    twikitopic=/canadia/twiki/data/Main/$deleteuser.txt
    echo "deleting twiki topic file $twikitopic"
    rm $twikitopic
    rm $twikitopic,v

fi

exit 0
