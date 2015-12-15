// Copyright 2010 Joshua C. Randall <jcrandall@alum.mit.edu>
// 
// This file is part of puzzlebitch.
//
// puzzlebitch is free software: you can redistribute it and/or modify
//    it under the terms of the GNU Affero General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    puzzlebitch is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU Affero General Public License for more details.
//
//    You should have received a copy of the GNU Affero General Public License
//	along with puzzlebitch.  If not, see <http://www.gnu.org/licenses/>.

import sample.appsforyourdomain.AppsForYourDomainClient;

import com.google.gdata.data.appsforyourdomain.*;

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

public class DeleteDomainUser {
    static DocsService client;
    static String adminUserString = "BigJimmy@stormynight.org";
    static String adminPassString = "";
    static String domainString = "stormynight.org";
    static String versionString = "canadia-DeleteDomainUser-0.2";
    static String commandlineString = "java DeleteDomainUser";
    static String userNameString = "BigJimmy";

    public static void main(String[] args) {
	// Get command-line arguments
	Options opt = new Options();
	opt.addOption(OptionBuilder.withLongOpt("username").withArgName("USERNAME").hasArg().isRequired().withDescription("Username to delete.").create("u"));
	opt.addOption(OptionBuilder.withLongOpt("domain").withArgName("DOMAIN").hasArg().isRequired().withDescription("Domain in which to create user.").create("d"));
	opt.addOption(OptionBuilder.withLongOpt("adminpass").withArgName("ADMINPASS").hasArg().isRequired().withDescription("Administrator password.").create("a"));
	try {
	    BasicParser parser = new BasicParser();
	    CommandLine cl = parser.parse(opt, args);
	    userNameString = cl.getOptionValue('u');
	    adminPassString = cl.getOptionValue('a');
	    domainString = cl.getOptionValue('d');
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
	System.out.println("Attempting to authenticate as user " + adminUserString);
	AppsForYourDomainClient client = null;
	try {
	    client = new AppsForYourDomainClient(adminUserString, adminPassString, domainString);
	} catch (AuthenticationException ae) {
	    ae.printStackTrace();
	    System.exit(-11);
	} catch (AppsForYourDomainException afyde) {
	    afyde.printStackTrace();
	    System.exit(-12);
	} catch (Exception e) {
	    e.printStackTrace();
	    System.exit(-13);
	}
	System.out.println("Domain admin user authenticated.");


	// Delete specified user
	try {
	    client.deleteUser(userNameString);
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	    System.exit(-21);
	} catch (AppsForYourDomainException afyde) {
	    afyde.printStackTrace();
	    System.exit(-22);
	} catch (ServiceException se) {
	    se.printStackTrace();
	    System.exit(-23);
	}
	System.out.println("User deleted.");
	System.exit(0);
    }
}
    
