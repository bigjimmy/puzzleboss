#!/usr/bin/python

import argparse
import json
import os
import sys 
import urllib
import codecs

import requests # pip install requests if you don't have it





def post_to_slack(url, text, channel, user, emoji, quiet):
    headers = {'content-type':'application/json'}
    payload = json.dumps({
            'channel' : channel,
            'username' : user,
            'text' : text,
            'icon_emoji' : emoji, 
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

    parser = argparse.ArgumentParser(description='Talk to Slack')
    parser.add_argument('-u','--url', 
        help='Slack Incoming Webhooks integration webhook URL.', required=True) 
    parser.add_argument('-c','--channel', help='Channel to post to', required=True)
    parser.add_argument('-n','--user', help='Name of the user to post as',
        required=True)
    parser.add_argument('-e','--emoji', help='Emoji to use for the message', 
        required=False, default=':rocket:')
    parser.add_argument('-q','--quiet', help='Work quietly if post successful',
        action='store_true')
    parser.add_argument('-g','--giphy', help='Output giphy search result based on text', action='store_true')
    parser.add_argument('-t','--text', help='Message to say. (uses stdin if not present)', required=False)
    parser.set_defaults(giphy=False)

    args = vars(parser.parse_args())

    # ensure emoji has starting/ending colon
    if not args['emoji'].startswith(':'):
        args['emoji'] = ":" + args['emoji'] 
    if not args['emoji'].endswith(':'):
        args['emoji'] = args['emoji'] + ":" 

    # ensure channel has pound sign
    if args['channel'][0] not in ['#', '@']:
        args['channel'] = '#' + args['channel']

    return args


def main():
    args = parse_args()
    if args['giphy']:
        text = args['text'] or "cat"
        giphydata = json.loads(urllib.urlopen("http://api.giphy.com/v1/gifs/search?q="+text+"&api_key=dc6zaTOxFJmzC").read())
	text = giphydata['data'][0]['images']['original']['url']
	post_to_slack(args['url'], text, args['channel'], args['user'], args['emoji'], args['quiet'])
    else:
        text = args['text'] or sys.stdin.read()
        post_to_slack(args['url'], text, args['channel'], args['user'], args['emoji'], args['quiet'])


if __name__ == "__main__":
    main()
