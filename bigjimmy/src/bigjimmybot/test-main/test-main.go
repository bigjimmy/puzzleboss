package main

import (
	"bigjimmybot"
	"flag"
	"time"
	"runtime"
	"strings"

	l4g "code.google.com/p/log4go"
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
var slackToken string
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

	// Google domain (optional, will be read from DB)
	flag.StringVar(&googleDomain, "google_domain", "", "Google Apps Domain")

	// slack token (optional , will be read from DB)
	flag.StringVar(&slackToken, "slack_token", "", "Token for Slack API access")
	
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
			l4g.Crashf("Could not get google_domain from DB: %v", err)
		}
	}
	d := &bigjimmybot.Drive{}
	log.Logf(l4g.TRACE, "main(): before open drive, %v goroutines.", runtime.NumGoroutine())
	d.OpenDrive(googleClientId, googleClientSecret, googleDomain, cacheFile)
	log.Logf(l4g.TRACE, "main(): after open drive, %v goroutines.", runtime.NumGoroutine())

	puzzle := &bigjimmybot.Puzzle{
	        Round: "RoundOne",
		Name: "JetFuelCantMeltSteelBeamsKnowYourMeme",
		Uri: "http://jet.fuel/",
	}

	log.Logf(l4g.INFO, "Calling SetInitialPuzzleSpreadsheetContents")
	err = d.SetInitialPuzzleSpreadsheetContents(puzzle, "14351oOnGWL7BV0FX-59hReu-OpdotFMpsguB_WlzxyI")
	log.Logf(l4g.INFO, "Back from SetInitialPuzzleSpreadsheetContents")
	if err != nil {
		log.Logf(l4g.ERROR, "Error setting initial puzzle spreadsheet: %v", err)
	} else {
		log.Logf(l4g.INFO, "Success")
	}
	log.Logf(l4g.INFO, "Done")
}

