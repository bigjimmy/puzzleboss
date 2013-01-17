import sample.appsforyourdomain.AppsForYourDomainClient;

import com.google.gdata.data.appsforyourdomain.*;
import com.google.gdata.data.appsforyourdomain.provisioning.UserEntry;

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

import org.apache.commons.cli.BasicParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.OptionBuilder;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.MissingOptionException;

public class ChangeUserPass {
    static DocsService client;
    static String adminUserString = "BigJimmy@stormynight.org";
    static String adminPassString = "";
    static String domainString = "stormynight.org";
    static String versionString = "canadia-ChangeUserPass-0.2";
    static String commandlineString = "java ChangeUserPass";
    static String usernameString = "BigJimmy";
    static String passwordString = "sexfantasy";
    static String hashedPasswordString = "";

    public static void main(String[] args) {
	// Get command-line arguments
	Options opt = new Options();
	opt.addOption(OptionBuilder.withLongOpt("username").withArgName("USERNAME").hasArg().isRequired().withDescription("Username to create.").create("u"));
	opt.addOption(OptionBuilder.withLongOpt("domain").withArgName("DOMAIN").hasArg().isRequired().withDescription("Domain in which to create user.").create("d"));
	opt.addOption(OptionBuilder.withLongOpt("password").withArgName("PASSWORD").hasArg().withDescription("Initial password for user.").create("p"));
	opt.addOption(OptionBuilder.withLongOpt("passwordhash").withArgName("PASSWORD_HASH").hasArg().withDescription("Initial password for user (SHA-1 hash).").create("ph"));
	opt.addOption(OptionBuilder.withLongOpt("adminuser").withArgName("ADMINUSER").hasArg().isRequired().withDescription("Administrator username (with @domain).").create("au"));
	opt.addOption(OptionBuilder.withLongOpt("adminpass").withArgName("ADMINPASS").hasArg().isRequired().withDescription("Administrator password.").create("ap"));
	try {
	    BasicParser parser = new BasicParser();
	    CommandLine cl = parser.parse(opt, args);
	    usernameString = cl.getOptionValue('u');
	    domainString = cl.getOptionValue('d');
	    passwordString = cl.getOptionValue('p');
	    hashedPasswordString = cl.getOptionValue("ph");
	    adminUserString = cl.getOptionValue("au");
	    adminPassString = cl.getOptionValue("ap");
	} catch (MissingOptionException moe) {
	    HelpFormatter formatter = new HelpFormatter();
	    formatter.printHelp( commandlineString, opt );
	    System.exit(1);
	} catch (ParseException pe) {
	    System.err.println( "Parsing failed.  Reason: " + pe.getMessage() );
	    System.exit(2);
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
	System.out.println("Attempting to authenticate as user " + adminUserString);
	AppsForYourDomainClient client = null;
	try {
	    client = new AppsForYourDomainClient(adminUserString, adminPassString, domainString);
	} catch (AuthenticationException ae) {
	    ae.printStackTrace();
	    System.exit(11);
	} catch (AppsForYourDomainException afyde) {
	    afyde.printStackTrace();
	    System.exit(12);
	} catch (Exception e) {
	    e.printStackTrace();
	    System.exit(13);
	}
	System.out.println("Domain admin user authenticated.");


	// retrieve existing user by username
	UserEntry existingUserEntry = null;
	try {
	    existingUserEntry = client.retrieveUser(usernameString);
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	    System.exit(21);
	} catch (AppsForYourDomainException afyde) {
	    afyde.printStackTrace();
	    System.exit(22);
	} catch (ServiceException se) {
	    se.printStackTrace();
	    System.exit(23);
	}

	// change user password
	if(hashedPasswordString == null || hashedPasswordString.length() == 0) { 
	    System.out.println("Using plaintext password.");
	    existingUserEntry.getLogin().setPassword(passwordString);
	} else {
	    System.out.println("Using password hash.");
	    existingUserEntry.getLogin().setPassword(hashedPasswordString);
	    existingUserEntry.getLogin().setHashFunctionName("SHA-1");
	}
	
        UserEntry updatedUserEntry = null;
	try {
	    updatedUserEntry = client.updateUser(usernameString, existingUserEntry);
        } catch (IOException ioe) {
            ioe.printStackTrace();
            System.exit(31);
	} catch (AppsForYourDomainException afyde) {
	    afyde.printStackTrace();
            System.exit(32);
        } catch (ServiceException se) {
	    se.printStackTrace();
            System.exit(33);
	}
	
	System.out.println("User password changed.");
	System.exit(0);
    }
}
    