#!/usr/bin/python
from __future__ import print_function
import httplib2
import os
import sys
import argparse
import hashlib
import json

from googleapiclient import discovery
import oauth2client
from oauth2client import client
from oauth2client import tools
from oauth2client import file


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
        credentials = tools.run_flow(flow, store, flags)
        print('Storing credentials to ' + credential_path)
    return credentials

def main():
    """
    Creates a Google Admin SDK API service object and changes user password
    """

    parser = argparse.ArgumentParser()
    parser.add_argument('-u', '--username', required=True)
    parser.add_argument('-d', '--domain', required=True)
    parser.add_argument('-p', '--password', required=True)
    args=parser.parse_args()
    passhash = hashlib.sha1(args.password).hexdigest()
    email = args.username+"@"+args.domain

    credentials = get_credentials()
    http = credentials.authorize(httplib2.Http())
    service = discovery.build('admin', 'directory_v1', http=http)

    print('Changing User Password:')
    print(' User Name:' + args.username)
    print(' Domain:' + args.domain)


    userbody={'password':args.password,'primaryEmail':email}
    jsonbody=json.dumps(userbody)
    print(' userkey:' + email)
    print(' userbody:' + jsonbody)
    userchanged = service.users().update(userKey=email, body=userbody).execute()

    if not userchanged:
        print('something happened. userchanged=Null')
    else:
	print('user password changed.  Return object:')
        print(userchanged)


if __name__ == '__main__':
    main()

