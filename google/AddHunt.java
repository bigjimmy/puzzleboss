//For document list API
import com.google.gdata.client.*;
import com.google.gdata.client.docs.*;
import com.google.gdata.data.MediaContent;
import com.google.gdata.data.PlainTextConstruct;
import com.google.gdata.data.acl.*;
import com.google.gdata.data.docs.*;
import com.google.gdata.data.extensions.*;
import com.google.gdata.util.*;
import java.net.*;
import java.io.*;
import java.net.URL;
import java.util.*;
import java.util.logging.*;
import sample.util.*;

//For Spreadsheets API
import com.google.gdata.client.spreadsheet.*;
import com.google.gdata.data.*;
import com.google.gdata.data.spreadsheet.*;
import com.google.gdata.util.*;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.net.URL;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

//For command line option parser
import org.apache.commons.cli.BasicParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.OptionBuilder;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.MissingOptionException;

public class AddHunt {
    static DocsService client;
    static String userString = "BigJimmy@stormynight.org";
    static String passString = "password";
    static String domainString = "stormynight.org";
    static String versionString = "stormynight-AddHunt-0.2";
    static String commandlineString = "java AddHunt";
    //this was to automagically set the sharing for new docs:    static String parentFolderResourceId = "folder:0B_xwlksahHvUZmMyNTljZmItMGY0Mi00ZjhhLWIxMTItNTM3OGQ2NDNkYTA0";
    static String huntString = "UnknownHunt";

    public static void main(String[] args) {
	// Get command-line arguments
	Options opt = new Options();
	opt.addOption(OptionBuilder.withLongOpt("domain").withArgName("DOMAIN").hasArg().isRequired().withDescription("Domain in which to create hunt.").create("d"));
	opt.addOption(OptionBuilder.withLongOpt("hunt").withArgName("HUNT_NAME").hasArg().isRequired().withDescription("Hunt Name (Root folder for new spreadsheet)").create("h"));
	opt.addOption(OptionBuilder.withLongOpt("adminpass").withArgName("ADMINPASS").hasArg().isRequired().withDescription("Administrator password.").create("a"));
	try {
	    BasicParser parser = new BasicParser();
	    CommandLine cl = parser.parse(opt, args);
	    domainString = cl.getOptionValue('d');
	    huntString = cl.getOptionValue('h');
	    passString = cl.getOptionValue('a');
	} catch (MissingOptionException moe) {
	    HelpFormatter formatter = new HelpFormatter();
	    formatter.printHelp( commandlineString, opt );
	    System.exit(-1);
	} catch (ParseException pe) {
	    System.err.println( "Parsing failed.  Reason: " + pe.getMessage() );
	    System.exit(-2);
	}
	
	/*
	Logger httpLogger = Logger.getLogger("com.google.gdata.client.http.HttpGDataRequest");
	httpLogger.setLevel(Level.ALL);
	Logger xmlLogger = Logger.getLogger("com.google.gdata.util.XmlParser");
	xmlLogger.setLevel(Level.ALL);
	ConsoleHandler logHandler = new ConsoleHandler();
	logHandler.setLevel(Level.ALL);
	httpLogger.addHandler(logHandler);
	xmlLogger.addHandler (logHandler);
	*/
	

	// Authenticate
	System.err.println("Attempting to authenticate as user " + userString);
	client = new DocsService(versionString);
	try {
	    client.setUserCredentials(userString, passString);
	} catch (AuthenticationException ae) {
	    ae.printStackTrace();
	    System.exit(-11);
	}
	System.err.println("User authenticated.");


	// Check for root folder and create if necessary
	System.err.println("Checking for root folder "+huntString);
	URL feedUri = null;
	try {
	    feedUri = new URL("https://docs.google.com/feeds/default/private/full/-/folder");
	} catch (MalformedURLException mue) {
	    mue.printStackTrace();
	    System.exit(-21);
	}
	DocumentQuery query = new DocumentQuery(feedUri);
	query.setTitleQuery(huntString);
	query.setTitleExact(true);
	query.setMaxResults(10);
	DocumentListFeed feed = null;
	try {
	    feed = client.getFeed(query, DocumentListFeed.class);
	} catch (MalformedURLException mue) {
	    mue.printStackTrace();
	    System.exit(-22);
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	    System.exit(-23);
	} catch (ServiceException se) {
	    se.printStackTrace();
	    System.exit(-24);
	}
	List<DocumentListEntry> rootFolderEntries = feed.getEntries();
	System.err.println("Found "+rootFolderEntries.size()+" folders called "+huntString);
	DocumentListEntry rootFolderEntry = null;
	if(rootFolderEntries.size() == 1) {
	    rootFolderEntry = rootFolderEntries.get(0);
	} else if(rootFolderEntries.size() > 1) {
	    System.err.println("WARNING: more than one root folder found with the same name, using first one!");
	    rootFolderEntry = rootFolderEntries.get(0);
	} else {
	    // Root folder does not exist yet, create it
	    System.err.println("Creating root folder "+huntString); 
	    try {
		//rootFolderEntry = createFolder(huntString,parentFolderResourceId);
		rootFolderEntry = createFolder(huntString);
	    } catch (IOException ioe) {
		ioe.printStackTrace();
		System.exit(-25);
	    } catch (ServiceException se) {
		se.printStackTrace();
		System.exit(-26);
	    }
	    System.err.println("Created root folder -- Document(" + rootFolderEntry.getResourceId() + "/" + rootFolderEntry.getTitle().getPlainText() + ")");
	    // Wait for root folder to appear in feed
	    System.err.print("Waiting for root folder to appear in feed...");
	    do {
		try {
		    feed = client.getFeed(query, DocumentListFeed.class);
		} catch (MalformedURLException mue) {
		    mue.printStackTrace();
		    System.exit(-27);
		} catch (IOException ioe) {
		    ioe.printStackTrace();
		    System.exit(-28);
		} catch (ServiceException se) {
		    se.printStackTrace();
		    System.exit(-29);
		}
		rootFolderEntries = feed.getEntries();
		if(rootFolderEntries.size() == 0) {
		    System.err.print(".");
		}
	    } while (rootFolderEntries.size() < 1);
	    System.err.println();
	}
	System.err.println("Have root folder -- Document(" + rootFolderEntry.getResourceId() + "/" + rootFolderEntry.getTitle().getPlainText() + ")");

	// update permissions to give whole domain writer privs
	System.err.println("Setting hunt folder ACL to allow domain-wide reads from users at "+domainString);
	setDomainAclRemoveDefault(rootFolderEntry, domainString, "reader");
	
	String huntFeedUriString = ((MediaContent) rootFolderEntry.getContent()).getUri();
	System.err.println("Have hunt root folder URI: " + huntFeedUriString);

	URL huntFeedUri = null;
	try {
	    huntFeedUri = new URL(huntFeedUriString);
	    System.err.println("Have root folder query URL: "+huntFeedUri.toString());
	} catch (MalformedURLException mue) {
	    mue.printStackTrace();
	    System.exit(-31);
	}

	String huntUriString = rootFolderEntry.getDocumentLink().getHref(); 
	System.out.println(huntUriString);
    }
    
    
    static public AclEntry addAclRole(AclRole role, AclScope scope, DocumentListEntry entry)
	throws IOException, MalformedURLException, ServiceException  {
	AclEntry aclEntry = new AclEntry();
	aclEntry.setRole(role);
	aclEntry.setScope(scope);
	
	return client.insert(new URL(entry.getAclFeedLink().getHref()), aclEntry);
    }

    static public DocumentListEntry createFolder(String title) throws IOException, ServiceException {
	DocumentListEntry newEntry = new FolderEntry();
	newEntry.setTitle(new PlainTextConstruct(title));
	URL feedUrl = new URL("https://docs.google.com/feeds/default/private/full/");
	return client.insert(feedUrl, newEntry);
    }

    static public DocumentListEntry createFolder(String title, String resource) throws IOException, ServiceException {
	DocumentListEntry newEntry = new FolderEntry();
	newEntry.setTitle(new PlainTextConstruct(title));
	URL feedUrl = new URL("https://docs.google.com/feeds/default/private/full/"+resource+"/contents");
	return client.insert(feedUrl, newEntry);
    }

    static public DocumentListEntry createNewDocument(String title, String type, URL uri)
	throws IOException, ServiceException {
	DocumentListEntry newEntry = null;
	if (type.equals("document")) {
	    newEntry = new DocumentEntry();
	} else if (type.equals("presentation")) {
	    newEntry = new PresentationEntry();
	} else if (type.equals("spreadsheet")) {
	    newEntry = new com.google.gdata.data.docs.SpreadsheetEntry();
	} else if (type.equals("folder")) {
	    newEntry = new FolderEntry();
	}
	newEntry.setTitle(new PlainTextConstruct(title));

	return client.insert(uri, newEntry);
    }

    static public DocumentListEntry createNewDocument(String title, String type)
	throws MalformedURLException, IOException, ServiceException {
	return createNewDocument(title, type, new URL("https://docs.google.com/feeds/default/private/full/"));
    }

    static public DocumentListEntry getMatchingEntry(DocumentListFeed feed, String matchTitleString, String matchTypeString) throws Exception {
	DocumentListEntry foundEntry = null;
	int foundCount = 0;
	for (DocumentListEntry entry : feed.getEntries()) {
	    String entryTitleString = entry.getTitle().getPlainText();
	    String entryTypeString = entry.getType();
	    //String resourceId = entry.getResourceId();
	    //System.err.println(" -- Document(" + resourceId + "/" + entry.getTitle().getPlainText() + ")");
	    //System.err.println("Have "+entryTypeString+" entry ["+entryTitleString+"]");
	    if(entryTypeString.equals(matchTypeString) && entryTitleString.equals(matchTitleString)) {
		String resourceId = entry.getResourceId(); 
		System.err.println("Identified matching "+entryTypeString+" entry "+entryTitleString+": "+resourceId);
		foundEntry = entry;
		foundCount++;
	    }
	}
	if(foundCount > 1) {
	    throw new Exception("Found multiple result entries ["+foundCount+"]");
	} else {
	    return foundEntry;
	}
    }

    static public void setDomainAclRemoveDefault(DocumentListEntry entry, String domainString, String roleString) {
	String aclFeedUriString = entry.getAclFeedLink().getHref();
	AclFeed aclFeed = null;
	try {
	    aclFeed = client.getFeed(new URL(aclFeedUriString), AclFeed.class);
	} catch (MalformedURLException mue) {
	    mue.printStackTrace();
	    System.exit(-132);
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	    System.exit(-133);
	} catch (ServiceException se) {
	    se.printStackTrace();
	    System.exit(-134);
	}
	for (AclEntry aclEntry : aclFeed.getEntries()) {
	    System.err.println("Have ACL entry: "+aclEntry.getScope().getValue() + " (" + aclEntry.getScope().getType() + ") : " + aclEntry.getRole().getValue());
	    // delete ACL for anyone-with-a-link: 'null (DEFAULT) : writer'
	    if(aclEntry.getScope().getType().toString().equals("DEFAULT")) {
		try {
		    // the update fails if it has withKey set (access with the link), delete it instead
		    aclEntry.delete();
		} catch (ServiceException se) {
		    se.printStackTrace();
		    System.exit(-201);
		} catch (UnsupportedOperationException uoe) {
		    uoe.printStackTrace();
		    System.exit(-202);
		} catch (IOException ioe) {
		    ioe.printStackTrace();
		    System.exit(-203);
		}
		System.err.println("DEFAULT ACL entry deleted");
	    }
	    
	    // delete DOMAIN entry for this domain unless the role is already writer
	    if(aclEntry.getScope().getType().toString().equals("DOMAIN") && aclEntry.getScope().getValue().toString().equals(domainString)) {
		if(aclEntry.getRole().toString().equals(roleString)) {
		    System.err.println("ACL entry for DOMAIN "+domainString+" is already "+roleString);
		} else {
		    // delete ACL so it can be added below
		    // NOTE: we need to delete and add rather than update because the update fails if it has withKey set (access with the link)
		    try {
			aclEntry.delete();
		    } catch (ServiceException se) {
			se.printStackTrace();
			System.exit(-201);
		    } catch (UnsupportedOperationException uoe) {
			uoe.printStackTrace();
			System.exit(-202);
		    } catch (IOException ioe) {
			ioe.printStackTrace();
			System.exit(-203);
		    }
		    System.err.println("ACL entry deleted");
		}
	    }
	}
	System.err.println("Adding ACL entry for spreadsheet to entire domain "+domainString);
	AclRole role = new AclRole(roleString);
	AclScope scope = new AclScope(AclScope.Type.DOMAIN, domainString);
	try {
	    AclEntry domainAclEntry = addAclRole(role, scope, entry);
	} catch (VersionConflictException vce) {
	    System.err.println("VersionConflictException: "+vce);
	    
	} catch (InvalidEntryException iee) {
	    System.err.println("InvalidEntryException");
	    iee.printStackTrace();
	    System.exit(-110);
	} catch (MalformedURLException mue) {
	    mue.printStackTrace();
	    System.exit(-111);
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	    System.exit(-112);
	} catch (ServiceException se) {
	    se.printStackTrace();
	    System.exit(-113);
	}
    }

    // helper function to dump documents in a list feed
    static public void printDocuments(DocumentListFeed feed) {
	for (DocumentListEntry entry : feed.getEntries()) {
	    String resourceId = entry.getResourceId();
	    System.err.println(" -- Document(" + resourceId + "/" + entry.getTitle().getPlainText() + ")");
	}
    }
}

