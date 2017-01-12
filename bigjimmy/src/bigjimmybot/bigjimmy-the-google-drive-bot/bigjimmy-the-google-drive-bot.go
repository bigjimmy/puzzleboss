package main

import (
	"bigjimmybot"
	"flag"
	l4g "code.google.com/p/log4go"
	"time"
	"runtime"
	"strings"
)

// Globals for command-line args 
var httpControlPort, httpControlPath string
var googleClientId, googleClientSecret, cacheFile string
var dbProtocol, dbHost, dbPort, dbName, dbUser, dbPassword string
var huntFolderTitle, huntFolderId string
var googleDomain string
var pbRestUri string
var maxConcHttpRestReqs int
var restRequestTimeoutSeconds time.Duration
var restRequestRetries int
var restRequestInitialRetryDelay time.Duration
var logLevel string

// Global for logging
var log l4g.Logger

// Other globals
var httpRestReqLimiter chan int

func init() {

	// database
	flag.StringVar(&dbProtocol, "dbprotocol", "tcp", "Database protocol")
	flag.StringVar(&dbHost, "dbhost", "localhost", "Database host")
	flag.StringVar(&dbPort, "dbport", "3306", "Database port")
	flag.StringVar(&dbName, "dbname", "puzzlebitch", "Database name")
	flag.StringVar(&dbUser, "dbuser", "", "Database user")
	flag.StringVar(&dbPassword, "dbpassword", "", "Database password")

	// HTTP control server 
	flag.StringVar(&httpControlPort, "http_control_port", "", "HTTP control port")
	flag.StringVar(&httpControlPath, "http_control_path", "", "HTTP control path")
	
	// authentication 
	flag.StringVar(&googleClientId, "google_client_id", "", "Client ID")
	flag.StringVar(&googleClientSecret, "google_client_secret", "", "Client Secret")
	flag.StringVar(&cacheFile, "cache", "bigjimmy-oauth-cache.json", "Token cache file")
	
	// hunt config (optional, will be read from DB)
	flag.StringVar(&huntFolderTitle, "pb_hunt_title", "", "Hunt Folder Title")
	flag.StringVar(&huntFolderId, "hunt_drive_id", "", "Hunt Folder Drive ID")

	// Google domain (otional, will be read from DB)
	flag.StringVar(&googleDomain, "google_domain", "", "Google Apps Domain")
	
	// PB settings (optional, will be read from DB)
	flag.StringVar(&pbRestUri, "pb_rest_uri", "", "Puzzlebitch REST interface URI")
	flag.IntVar(&maxConcHttpRestReqs, "max_concurrent_req", 15, "Maximum concurrest HTTP REST requests")

	// Not yet in DB - TODO: add to config DB
	flag.DurationVar(&restRequestTimeoutSeconds, "rest_request_timeout", 60 * time.Second, "Timeout for HTTP REST requests")
	flag.IntVar(&restRequestRetries, "rest_request_retries", 3, "Number of times to retry each REST request")
	flag.DurationVar(&restRequestInitialRetryDelay, "rest_request_initial_retry_time", 2 * time.Second, "Delay before first retry of a REST request")

	// Log verbosity
	flag.StringVar(&logLevel, "log_level", "info", "Log level (error, warning, info, debug, trace)")

	// channels
	httpRestReqLimiter = make(chan int, maxConcHttpRestReqs)
	bigjimmybot.SetRestReqLimiter(httpRestReqLimiter)
}

const usageMsg = `
To obtain a request token you must specify both -google_client_id and -google_client_secret after which 
an auth token will be stored in the -cache file. 

You can assign or lookup a client ID from the Google APIs console: https://code.google.com/apis/console/ under the API access tab.
`


func main() {
	flag.Parse()

	// Initialize logger
	logLevel = strings.ToLower(logLevel)
	switch {
	  case logLevel == "trace":
	    log = l4g.NewDefaultLogger(l4g.TRACE)
	  case logLevel == "debug":
	    log = l4g.NewDefaultLogger(l4g.DEBUG)
	  case logLevel == "info":
	    log = l4g.NewDefaultLogger(l4g.INFO)
	  case logLevel == "warning":
	    log = l4g.NewDefaultLogger(l4g.WARNING)
	  case logLevel == "error":
	    log = l4g.NewDefaultLogger(l4g.ERROR)
	}
	//log.AddFilter("log", l4g.FINE, l4g.NewFileLogWriter("example.log", true))
	bigjimmybot.SetLog(log)

	// Connect to DB
	log.Logf(l4g.TRACE, "main(): before OpenDB, %v goroutines.", runtime.NumGoroutine())
	bigjimmybot.OpenDB(dbUser, dbPassword, dbProtocol, dbHost, dbPort, dbName)
	defer bigjimmybot.CloseDB()
	log.Logf(l4g.TRACE, "main(): after OpenDB, %v goroutines.", runtime.NumGoroutine())

	var err error

	// Connect to Drive
	// Ensure we have googleClientId and googleClientSecret (from command-line args or DB)
	log.Logf(l4g.TRACE, "main(): before getting client id and secret, %v goroutines.", runtime.NumGoroutine())
	if googleClientId == "" {
		googleClientId, err = bigjimmybot.DbGetConfig("GOOGLE_CLIENT_ID")	
		if err != nil {
			log.Logf(l4g.ERROR, "attempt to get googleClientId from DB failed: %v", err)
		}
	}
	if googleClientSecret == "" {
		googleClientSecret, err = bigjimmybot.DbGetConfig("GOOGLE_CLIENT_SECRET")
		if err != nil {
			log.Logf(l4g.ERROR, "attempt to get googleClientSecret from DB failed: %v", err)
		}
	}
	if googleClientId == "" || googleClientSecret == "" {
		log.Logf(l4g.ERROR, "Please specify -google_client_id and -google_client_secret (or ensure they are in the DB and database connection is working)")
		flag.Usage()
		l4g.Crashf(usageMsg)
	} else {
		log.Logf(l4g.INFO, "Using google_client_id=%v and google_client_secret=%v", googleClientId, googleClientSecret)
	}
	// Try to get google_domain (for permissions) from DB
	if googleDomain == "" {
		googleDomain, err = bigjimmybot.DbGetConfig("GOOGLE_DOMAIN")
		if err != nil {
			l4g.Crashf("Could not get pb_rest_uri from DB: %v", err)
		}
	}
	log.Logf(l4g.TRACE, "main(): before open drive, %v goroutines.", runtime.NumGoroutine())
	bigjimmybot.OpenDrive(googleClientId, googleClientSecret, googleDomain, cacheFile)
	log.Logf(l4g.TRACE, "main(): after open drive, %v goroutines.", runtime.NumGoroutine())


	// Setup PB REST client
	// Get pbRestUri if we don't have it
	if pbRestUri == "" {
		pbRestUri, err = bigjimmybot.DbGetConfig("PB_REST_URI")
		if err != nil {
			l4g.Crashf("Could not get pb_rest_uri from DB: %v", err)
		}
	}
	bigjimmybot.SetPbRestUri(pbRestUri)

	// Get huntFolderId (either from command-line, from database, or from Google Drive if we have title)
	// Ensure we can get huntFolderId (from command-line arg, DB, or via huntFolderTitle)
	if huntFolderId == "" {
		huntFolderId, _ = bigjimmybot.DbGetConfig("google_hunt_folder_id")
	}
	if huntFolderId == "" && huntFolderTitle == "" {
		// still don't have huntFolderId, and we don't have title either
		// try to get title from DB
		huntFolderTitle, _ = bigjimmybot.DbGetConfig("PB_HUNT")
	} else if huntFolderId != "" && huntFolderTitle != "" {
		log.Logf(l4g.INFO, "you specified hunt_folder_title but we have hunt_folder_id so it is being ignored.")
		huntFolderTitle = ""
	}
	log.Logf(l4g.TRACE, "main(): before getting hunt folder id, %v goroutines.", runtime.NumGoroutine())
	if huntFolderId == "" && huntFolderTitle != "" {
		// huntFolderId neither specified nor in DB, but we do have title
		// so get hunt folder ID from Google by looking it up by title
		// or create it if it does not exist
		log.Logf(l4g.INFO, "looking up google docs folder id for title %v", huntFolderTitle)
		huntFolderId, err = bigjimmybot.GetFolderIdByTitle(huntFolderTitle)
		if err != nil {
			if err, ok := err.(*bigjimmybot.ListError); ok {
				if err.Found > 1 {
					l4g.Crashf("more than one document matches %v", huntFolderTitle)
				} else if err.Found == 0 {
				        //l4g.Crashf("no hunt folder found for %v", huntFolderTitle)
					log.Logf(l4g.INFO, "no hunt folder found for %v, creating it", huntFolderTitle)
					var cferr error
					huntFolderId, _, cferr = bigjimmybot.CreateHunt(huntFolderTitle)
					if cferr != nil {
						l4g.Crashf("could not create hunt folder for title [%v]: %v", huntFolderTitle, cferr)
					}
					log.Logf(l4g.INFO, "hunt folder created")
				}
			} else {
				l4g.Crashf("an error occurred getting hunt folder ID: %v", err)
			}
		}
		log.Logf(l4g.INFO, "hunt_folder_id: %v", huntFolderId)
		// DB doesn't yet have huntFolderId, set it if we have it 
		if huntFolderId != "" {
			err = bigjimmybot.DbSetConfig("google_hunt_folder_id", huntFolderId)
			if err != nil {
				l4g.Crashf("could not set hunt_folder_id in DB")
			}
		}
	}
	log.Logf(l4g.TRACE, "main(): after getting hunt folder id, %v goroutines.", runtime.NumGoroutine())
	// set huntFolderId in bigjimmybot
	bigjimmybot.SetHuntFolderId(huntFolderId)

	// get initial version diff
	log.Logf(l4g.TRACE, "main(): before bigjimmybot.PbGetInitialVersionDiff %v goroutines.", runtime.NumGoroutine())
	bigjimmybot.PbGetInitialVersionDiff()
	log.Logf(l4g.TRACE, "main(): after bigjimmybot.PbGetInitialVersionDiff %v goroutines.", runtime.NumGoroutine())

	// Start ControlServer main loop
	// Ensure we have httpControlPort and httpControlPath
	log.Logf(l4g.TRACE, "main(): before ensuring httpControlPort and httpControlPath %v goroutines.", runtime.NumGoroutine())
	if httpControlPort == "" {
		httpControlPort, err = bigjimmybot.DbGetConfig("BIGJIMMY_CONTROL_PORT")	
		if err != nil {
			log.Logf(l4g.ERROR, "attempt to get httpControlPort from DB failed: %v", err)
		}
	}
	if httpControlPath == "" {
		httpControlPath, err = bigjimmybot.DbGetConfig("BIGJIMMY_CONTROL_PATH")
		if err != nil {
			log.Logf(l4g.ERROR, "attempt to get httpControlPath from DB failed: %v", err)
		}
	}
	if httpControlPort == "" || httpControlPath == "" {
		log.Logf(l4g.ERROR, "Please specify -http_control_port and -http_control_path (or ensure they are in the DB and database connection is working)")
		flag.Usage()
		l4g.Crashf(usageMsg)
	} else {
		log.Logf(l4g.INFO, "Using http_control_port=%v and http_control_path=%v", httpControlPort, httpControlPath)
	}
	log.Logf(l4g.TRACE, "main(): after ensuring httpControlPort and httpControlPath %v goroutines.", runtime.NumGoroutine())

	time.Sleep(5*time.Second)
	log.Logf(l4g.TRACE, "main(): before bigjimmybot.ControlServer %v goroutines.", runtime.NumGoroutine())
	bigjimmybot.ControlServer(httpControlPort, httpControlPath)
	log.Logf(l4g.TRACE, "main(): after bigjimmybot.ControlServer %v goroutines.", runtime.NumGoroutine())
}

