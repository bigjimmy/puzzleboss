#!/usr/bin/python

import argparse
import json
import os
import sys 
import urllib
import codecs

import requests # pip install requests if you don't have it

def post_to_slack(url, text, quiet):
    headers = {'content-type':'application/json'}
    payload = json.dumps({
            'content' : text,
    })

    # if you don't want the dependency on the requests library, you can use the
    # standard library here:
    # import urllib2
    #request = urllib2.Request(url, payload, headers) 
    #f = urllib2.urlopen(request)
    #response = f.read()
    #f.close() 
    # print response

    # but requests is much nicer, particulary if there's an error
    request = requests.post(url, headers=headers, data=payload)
    if request.status_code == 200 and quiet :
        # suppress output on successful post
        pass
    else :
        print "Response: %s - %s" % (request.status_code, request.reason)


def parse_args():

    parser = argparse.ArgumentParser(description='Talk to Discord')
    parser.add_argument('-u','--url', 
        help='Incoming Webhook integration webhook URL.', required=True) 
    parser.add_argument('-q','--quiet', help='Work quietly if post successful',
        action='store_true')
    parser.add_argument('-t','--text', help='Message to say. (uses stdin if not present)', required=False)
    parser.set_defaults(giphy=False)

    args = vars(parser.parse_args())

    return args


def main():
    args = parse_args()
    text = args['text'] or sys.stdin.read()
    post_to_slack(args['url'], text, args['quiet'])


if __name__ == "__main__":
    main()
