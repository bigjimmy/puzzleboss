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

//For command line option parser
import org.apache.commons.cli.BasicParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.OptionBuilder;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.MissingOptionException;

public class DeleteEntries {
    static DocsService client;
    static String userString = "BigJimmy@stormynight.org";
    static String passString = "";
    static String domainString = "stormynight.org";
    static String versionString = "stormynight-AddPuzzleSpreadsheet-0.2";
    static String commandlineString = "java AddPuzzleSpreadsheet";
    //    static String parentFolderResourceId = "folder:0B_xwlksahHvUZmMyNTljZmItMGY0Mi00ZjhhLWIxMTItNTM3OGQ2NDNkYTA0";
    static String deleteEntryString = "UnknownToBeDeletedNow";

    public static void main(String[] args) {
	// Get command-line arguments
	Options opt = new Options();
	opt.addOption(OptionBuilder.withLongOpt("domain").withArgName("DOMAIN").hasArg().isRequired().withDescription("Domain in which to add round.").create("d"));
	opt.addOption(OptionBuilder.withLongOpt("entry").withArgName("PUZZLE_NAME").hasArg().isRequired().withDescription("Entry name to delete").create("e"));
	opt.addOption(OptionBuilder.withLongOpt("adminpass").withArgName("ADMINPASS").hasArg().isRequired().withDescription("Administrator password.").create("a"));
	try {
	    BasicParser parser = new BasicParser();
	    CommandLine cl = parser.parse(opt, args);
	    domainString = cl.getOptionValue('d');
	    deleteEntryString = cl.getOptionValue('e');
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
	URL feedUri = null;
	try {
	    feedUri = new URL("https://docs.google.com/feeds/default/private/full/-/folder");
	} catch (MalformedURLException mue) {
	    mue.printStackTrace();
	    System.exit(-21);
	}
	DocumentQuery query = new DocumentQuery(feedUri);
	query.setTitleQuery(deleteEntryString);
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
	List<DocumentListEntry> deleteEntries = feed.getEntries();
	System.err.println("Found "+deleteEntries.size()+" entries called "+deleteEntryString);
	for (DocumentListEntry entry : deleteEntries) {
	    String entryTitleString = entry.getTitle().getPlainText();
	    String entryTypeString = entry.getType();
	    System.err.print("Deleting "+entryTypeString+" named "+entryTitleString+"...");
	    try {
		client.delete(new URL(entry.getEditLink().getHref() + "?delete=true"), entry.getEtag()); // delete it for reals
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
	    System.err.println("done");
	}
	
    }

}