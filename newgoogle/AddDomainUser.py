#!/usr/bin/python
from __future__ import print_function
import httplib2
import os
import sys
import argparse
import hashlib
import json

from apiclient import discovery
import oauth2client
from oauth2client import client
from oauth2client import tools


SCOPES = 'https://www.googleapis.com/auth/admin.directory.user'
CLIENT_SECRET_FILE = 'client_secret.json'
APPLICATION_NAME = 'Puzzlebitch Scripts'


def get_credentials():
    """Gets valid user credentials from storage.

    If nothing has been stored, or if the stored credentials are invalid,
    the OAuth2 flow is completed to obtain the new credentials.

    Returns:
        Credentials, the obtained credential.
    """
    credential_dir = '/canadia/puzzlebitch/googcredentials'
    if not os.path.exists(credential_dir):
        os.makedirs(credential_dir)
    credential_path = os.path.join(credential_dir,
                                   'admin-directory_v1-python.json')

    store = oauth2client.file.Storage(credential_path)
    credentials = store.get()
    if not credentials or credentials.invalid:
        flow = client.flow_from_clientsecrets(CLIENT_SECRET_FILE, SCOPES)
        flow.user_agent = APPLICATION_NAME
        if flags:
            credentials = tools.run_flow(flow, store, flags)
        else: # Needed only for compatibility with Python 2.6
            credentials = tools.run(flow, store)
        print('Storing credentials to ' + credential_path)
    return credentials

def main():
    """
    Creates a Google Admin SDK API service object and adds one user
    """

    parser = argparse.ArgumentParser()
    parser.add_argument('-u', '--username', required=True)
    parser.add_argument('-d', '--domain', required=True)
    parser.add_argument('-p', '--password', required=True)
    parser.add_argument('-f', '--firstname', required=True)
    parser.add_argument('-l', '--lastname', required=True)
    args=parser.parse_args()
    passhash = hashlib.sha1(args.password).hexdigest()
    email = args.username+"@"+args.domain

    credentials = get_credentials()
    http = credentials.authorize(httplib2.Http())
    service = discovery.build('admin', 'directory_v1', http=http)

    print('Adding User:')
    print(' User Name:' + args.username)
    print(' Domain:' + args.domain)
    print(' First Name:' + args.firstname)
    print(' Last Name:' + args.lastname)

    userbody={'name':{ 'familyName':args.lastname,'givenName':args.firstname },'password':args.password,'primaryEmail':email}
    jsonbody=json.dumps(userbody)
    useradded = service.users().insert(body=userbody).execute()

    if not useradded:
        print('something happened. useradded=Null')
    else:
	print('user added.  Return object:')
        print(useradded)


if __name__ == '__main__':
    main()

