#!/usr/bin/python

############################
#
# pbmail_inbox_discord.py
#
# Python script to take a multi-part MIME email via stdin and send it to slack
#
############################

import sys, os, re, StringIO
import email,mimetypes
import json
import requests
import codecs

BOT_USERNAME = 'mailbot'
WEBHOOK_URL = codecs.encode('uggcf://qvfpbeq.pbz/ncv/jroubbxf/790401743669690428/MdtwJs-nCoMhHQttusBx8i7-GefgpCDSDHUYmR7HaBp0Ztr68pbnoGjWpHBCZVIZ45P_','rot_13')
BOT_CHANNEL = '#mailinglist'
FILENAME = '/var/tmp/lastpuzzbossmaildiscord'
OUTFILE = '/var/tmp/lastpuzzpossmailtextdiscord'

invalid_chars_in_filename='<>:"/\\|?*\%\''+reduce(lambda x,y:x+chr(y), range(32), '')
invalid_windows_name='CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9'.split()

# email address REGEX matching the RFC 2822 spec from perlfaq9
#    my $atom       = qr{[a-zA-Z0-9_!#\$\%&'*+/=?\^`{}~|\-]+};
#    my $dot_atom   = qr{$atom(?:\.$atom)*};
#    my $quoted     = qr{"(?:\\[^\r\n]|[^\\"])*"};
#    my $local      = qr{(?:$dot_atom|$quoted)};
#    my $domain_lit = qr{\[(?:\\\S|[\x21-\x5a\x5e-\x7e])*\]};
#    my $domain     = qr{(?:$dot_atom|$domain_lit)};
#    my $addr_spec  = qr{$local\@$domain};
# 
# Python's translation

atom_rfc2822=r"[a-zA-Z0-9_!#\$\%&'*+/=?\^`{}~|\-]+"
atom_posfix_restricted=r"[a-zA-Z0-9_#\$&'*+/=?\^`{}~|\-]+" # without '!' and '%'
atom=atom_rfc2822
dot_atom=atom  +  r"(?:\."  +  atom  +  ")*"
quoted=r'"(?:\\[^\r\n]|[^\\"])*"'
local="(?:"  +  dot_atom  +  "|"  +  quoted  +  ")"
domain_lit=r"\[(?:\\\S|[\x21-\x5a\x5e-\x7e])*\]"
domain="(?:"  +  dot_atom  +  "|"  +  domain_lit  +  ")"
addr_spec=local  +  "\@"  +  domain

email_address_re=re.compile('^'+addr_spec+'$')

class Attachment:
    def __init__(self, part, filename=None, type=None, payload=None, charset=None, content_id=None, description=None, disposition=None, sanitized_filename=None, is_body=None):
        self.part=part          # original python part
        self.filename=filename  # filename in unicode (if any) 
        self.type=type          # the mime-type
        self.payload=payload    # the MIME decoded content 
        self.charset=charset    # the charset (if any) 
        self.description=description    # if any 
        self.disposition=disposition    # 'inline', 'attachment' or None
        self.sanitized_filename=sanitized_filename # cleanup your filename here (TODO)  
        self.is_body=is_body        # usually in (None, 'text/plain' or 'text/html')
        self.content_id=content_id  # if any
        if self.content_id:
            # strip '<>' to ease searche and replace in "root" content (TODO) 
            if self.content_id.startswith('<') and self.content_id.endswith('>'):
                self.content_id=self.content_id[1:-1]

def getmailheader(header_text, default="ascii"):
    """Decode header_text if needed"""
    try:
        headers=email.Header.decode_header(header_text)
    except email.Errors.HeaderParseError:
        # This already append in email.base64mime.decode()
        # instead return a sanitized ascii string
        # this faile '=?UTF-8?B?15HXmdeh15jXqNeVINeY15DXpteUINeTJ9eV16jXlSDXkdeg15XXldeUINem15PXpywg15TXptei16bXldei15nXnSDXqdecINek15zXmdeZ?==?UTF-8?B?157XldeR15nXnCwg157Xldek16Ig157Xl9eV15wg15HXodeV15bXnyDXk9ec15DXnCDXldeh15gg157Xl9eR16rXldeqINep15wg15HXmdeQ?==?UTF-8?B?15zXmNeZ?='
        return header_text.encode('ascii', 'replace').decode('ascii')
    else:
        for i, (text, charset) in enumerate(headers):
            try:
                headers[i]=unicode(text, charset or default, errors='replace')
            except LookupError:
                # if the charset is unknown, force default 
                headers[i]=unicode(text, default, errors='replace')
        return u"".join(headers)

def getmailaddresses(msg, name):
    """retrieve addresses from header, 'name' supposed to be from, to,  ..."""
    addrs=email.utils.getaddresses(msg.get_all(name, []))
    for i, (name, addr) in enumerate(addrs):
        if not name and addr:
            # only one string! Is it the address or is it the name ?
            # use the same for both and see later
            name=addr
            
        try:
            # address must be ascii only
            addr=addr.encode('ascii')
        except UnicodeError:
            addr=''
        else:
            # address must match address regex
            if not email_address_re.match(addr):
                addr=''
        addrs[i]=(getmailheader(name), addr)
    return addrs

def get_filename(part):
    """Many mail user agents send attachments with the filename in 
    the 'name' parameter of the 'content-type' header instead 
    of in the 'filename' parameter of the 'content-disposition' header.
    """
    filename=part.get_param('filename', None, 'content-disposition')
    if not filename:
        filename=part.get_param('name', None) # default is 'content-type'
        
    if filename:
        # RFC 2231 must be used to encode parameters inside MIME header
        filename=email.Utils.collapse_rfc2231_value(filename).strip()

    if filename and isinstance(filename, str):
        # But a lot of MUA erroneously use RFC 2047 instead of RFC 2231
        # in fact anybody miss use RFC2047 here !!!
        filename=getmailheader(filename)
        
    return filename

def _search_message_bodies(bodies, part):
    """recursive search of the multiple version of the 'message' inside 
    the the message structure of the email, used by search_message_bodies()"""
    
    type=part.get_content_type()
    if type.startswith('multipart/'):
        # explore only True 'multipart/*' 
        # because 'messages/rfc822' are also python 'multipart' 
        if type=='multipart/related':
            # the first part or the one pointed by start 
            start=part.get_param('start', None)
            related_type=part.get_param('type', None)
            for i, subpart in enumerate(part.get_payload()):
                if (not start and i==0) or (start and start==subpart.get('Content-Id')):
                    _search_message_bodies(bodies, subpart)
                    return
        elif type=='multipart/alternative':
            # all parts are candidates and latest is best
            for subpart in part.get_payload():
                _search_message_bodies(bodies, subpart)
        elif type in ('multipart/report',  'multipart/signed'):
            # only the first part is candidate
            try:
                subpart=part.get_payload()[0]
            except IndexError:
                return
            else:
                _search_message_bodies(bodies, subpart)
                return

        elif type=='multipart/signed':
            # cannot handle this
            return
            
        else: 
            # unknown types must be handled as 'multipart/mixed'
            # This is the peace of code could probably be improved, I use a heuristic : 
            # - if not already found, use first valid non 'attachment' parts found
            for subpart in part.get_payload():
                tmp_bodies=dict()
                _search_message_bodies(tmp_bodies, subpart)
                for k, v in tmp_bodies.iteritems():
                    if not subpart.get_param('attachment', None, 'content-disposition')=='':
                        # if not an attachment, initiate value if not already found
                        bodies.setdefault(k, v)
            return
    else:
        bodies[part.get_content_type().lower()]=part
        return
    
    return

def search_message_bodies(mail):
    """search message content into a mail"""
    bodies=dict()
    _search_message_bodies(bodies, mail)
    return bodies

def get_mail_contents(msg):
    """split an email in a list of attachments"""

    attachments=[]

    # retrieve messages of the email
    bodies=search_message_bodies(msg)
    # reverse bodies dict
    parts=dict((v,k) for k, v in bodies.iteritems())

    # organize the stack to handle deep first search
    stack=[ msg, ]
    while stack:
        part=stack.pop(0)
        type=part.get_content_type()
        if type.startswith('message/'): 
            # ('message/delivery-status', 'message/rfc822', 'message/disposition-notification'):
            # I don't want to explore the tree deeper her and just save source using msg.as_string()
            # but I don't use msg.as_string() because I want to use mangle_from_=False 
            from email.Generator import Generator
            fp = StringIO.StringIO()
            g = Generator(fp, mangle_from_=False)
            g.flatten(part, unixfrom=False)
            payload=fp.getvalue()
            filename='mail.eml'
            attachments.append(Attachment(part, filename=filename, type=type, payload=payload, charset=part.get_param('charset'), description=part.get('Content-Description')))
        elif part.is_multipart():
            # insert new parts at the beginning of the stack (deep first search)
            stack[:0]=part.get_payload()
        else:
            payload=part.get_payload(decode=True)
            charset=part.get_param('charset')
            filename=get_filename(part)
                
            disposition=None
            if part.get_param('inline', None, 'content-disposition')=='':
                disposition='inline'
            elif part.get_param('attachment', None, 'content-disposition')=='':
                disposition='attachment'
                
            attachments.append(Attachment(part, filename=filename, type=type, payload=payload, charset=charset, content_id=part.get('Content-Id'), description=part.get('Content-Description'), disposition=disposition, is_body=parts.get(part)))

    return attachments

def decode_text(payload, charset, default_charset):
    if charset:
        try: 
            return payload.decode(charset), charset
        except UnicodeError:
            pass

    if default_charset and default_charset!='auto':
        try: 
            return payload.decode(default_charset), default_charset
        except UnicodeError:
            pass
        
    for chset in [ 'ascii', 'utf-8', 'utf-16', 'windows-1252', 'cp850' ]:
        try: 
            return payload.decode(chset), chset
        except UnicodeError:
            pass

    return payload, None

def post_to_slack(url, text):
    """Construct message into json and post it to slack"""
    headers = {'content-type':'application/json'}
    payload = json.dumps({
            'content' : text,
    })

    request = requests.post(url, headers=headers, data=payload)
    if request.status_code == 200:
        # suppress output on successful post
        pass
    else :
        print "Response: %s - %s" % (request.status_code, request.reason)
	print "FullResp: %r" % (request.raw.read(50))


if __name__ == "__main__":

    # First just dump the raw email into a file
    f = open(FILENAME, 'w')
    for line in sys.stdin:
        f.write(line)
    f.close()

    # Then parse the raw email file into MIME parts 
    raw=open(FILENAME).read()
    msg=email.message_from_string(raw)
    attachments=get_mail_contents(msg)
    
    # Extract headers
    subject=getmailheader(msg.get('Subject', ''))
    from_=getmailaddresses(msg, 'from')
    from_=('', '') if not from_ else from_[0]
    tos=getmailaddresses(msg, 'to')
    
    # Redirect stdout to outfile for plaintext message
    outf=open(OUTFILE, 'w')
    sys.stdout = outf
    
    print ('Subject: ' + subject)
    print ('From: ' + from_[1])
    #print ('To: ' + tos,) 
    print (' ')

    for attach in attachments:
 
	if attach.filename:
           #print '\tFile: %s type=%s charset=%s desc=%s size=%d' % (attach.filename, attach.type, attach.charset, attach.description, 0 if attach.payload==None else len(attach.payload))
           print ('[File attached]')
        if attach.is_body=='text/plain':
            payload, used_charset=decode_text(attach.payload, attach.charset, 'auto')
            for line in payload.split('\n')[:75]:
                if line:
		    if not (re.match("^>", line)):
                        if not (re.match("^On\ .*\<.*@.*>.*:$", line)):
			    #fucking unicode
                            fixedline=line.replace(u"\u2019", "'").replace(u"\u201C", "'").replace(u"\u2026", "...").replace(u"\u201D", "'").replace(u"\u2018", "'").replace(u"\u2014", "--")
                            try:
			        newline=fixedline.encode('iso-8859-15')
                            except UnicodeError:
                                newline="[Unicode error in message, line omitted]"                             
                            print '\t\t', newline
		             
   
    outf.close()
    sys.stdout = sys.__stdout__
    
    # now take that plaintext rendered message and send it to slack
    toslackf=open(OUTFILE, 'r')
    slackmessage=toslackf.read()
    toslackf.close()
    post_to_slack(WEBHOOK_URL, slackmessage)



#!/usr/bin/python

