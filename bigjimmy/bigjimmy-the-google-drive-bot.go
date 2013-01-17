package main

import (
	"bigjimmybot"
	"strings"
	"code.google.com/p/goauth2/oauth"
	"code.google.com/p/google-api-go-client/drive/v2"
	"flag"
	"fmt"
	"crypto/tls"
	"net/http"
	"html"
	"encoding/json"
	"database/sql"
	"strconv"
	_ "github.com/Go-SQL-Driver/MySQL"
	l4g "code.google.com/p/log4go"
	"github.com/jmcvetta/restclient"
)

// Globals for command-line args 
var httpControlPort, httpControlPath string
var googleClientId, googleClientSecret, cacheFile string
var dbProtocol, dbHost, dbPort, dbName, dbUser, dbPassword string
var huntFolderTitle, huntFolderId string
var pbRestUri string
var maxConcHttpRestReqs int

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
	
	// PB settings (otional, will be read from DB)
	flag.StringVar(&pbRestUri, "pb_rest_uri", "", "Puzzlebitch REST interface URI")
	flag.StringVar(&maxConcHttpRestReqs, "max_concurrent_req", 10, "Maximum concurrest HTTP REST requests")

	
	// Initialize logger
	log = l4g.NewDefaultLogger(l4g.DEBUG)
	//log.AddFilter("log", l4g.FINE, l4g.NewFileLogWriter("example.log", true)) 
	// Initialize http transport
	tr := &http.Transport{
		TLSClientConfig:    &tls.Config{RootCAs: nil},
	}
	httpClient = &http.Client{Transport: tr}

	// channels
	httpRestReqLimiter = make(chan int, maxConcHttpRestReqs)
}

const usageMsg = `
To obtain a request token you must specify both -google_client_id and -google_client_secret after which 
an auth token will be stored in the -cache file. 

You can assign or lookup a client ID from the Google APIs console: https://code.google.com/apis/console/ under the API access tab.
`

//globals
var version int64 = 0
var httpClient *http.Client


// Uploads a file to Google Drive
func main() {
	flag.Parse()
	
	// Connect to database
	mysqlDsn := dbUser+":"+dbPassword+"@"+dbProtocol+"("+dbHost+":"+dbPort+")/"+dbName
	con, err := sql.Open("mysql", mysqlDsn)
	if err != nil {
		l4g.Crashf("could not connect to mysql database with DSN %v: %v\n", mysqlDsn, err)
	}
	defer con.Close()


	// Ensure we have googleClientId and googleClientSecret (from command-line args or DB)
	if googleClientId == "" {
		googleClientId, err = dbGetConfig(con, "GOOGLE_CLIENT_ID")	
		if err != nil {
			log.Logf(l4g.INFO, "attempt to get googleClientId from DB failed: %v\n", err)
		}
	}
	if googleClientSecret == "" {
		googleClientSecret, err = dbGetConfig(con, "GOOGLE_CLIENT_SECRET")
		if err != nil {
			log.Logf(l4g.INFO, "attempt to get googleClientSecret from DB failed: %v\n", err)
		}
	}
	if googleClientId == "" || googleClientSecret == "" {
		log.Logf(l4g.INFO, "Please specify -google_client_id and -google_client_secret (or ensure they are in the DB and database connection is working)\n")
		flag.Usage()
		l4g.Crashf(usageMsg)
	} else {
		log.Logf(l4g.INFO, "Using google_client_id=%v and google_client_secret=%v\n", googleClientId, googleClientSecret)
	}

	// Ensure we have httpControlPort and httpControlPath
	if httpControlPort == "" {
		httpControlPort, err = dbGetConfig(con, "BIGJIMMY_CONTROL_PORT")	
		if err != nil {
			log.Logf(l4g.INFO, "attempt to get httpControlPort from DB failed: %v\n", err)
		}
	}
	if httpControlPath == "" {
		httpControlPath, err = dbGetConfig(con, "BIGJIMMY_CONTROL_PATH")
		if err != nil {
			log.Logf(l4g.INFO, "attempt to get httpControlPath from DB failed: %v\n", err)
		}
	}
	if httpControlPort == "" || httpControlPath == "" {
		log.Logf(l4g.INFO, "Please specify -http_control_port and -http_control_path (or ensure they are in the DB and database connection is working)\n")
		flag.Usage()
		l4g.Crashf(usageMsg)
	} else {
		log.Logf(l4g.INFO, "Using http_control_port=%v and http_control_path=%v\n", httpControlPort, httpControlPath)
	}
	
	// Settings for Google authorization.
	config := &oauth.Config{
		ClientId:     googleClientId,
		ClientSecret: googleClientSecret,
		Scope:        "https://www.googleapis.com/auth/drive",
		RedirectURL:  "urn:ietf:wg:oauth:2.0:oob",
		AuthURL:      "https://accounts.google.com/o/oauth2/auth",
		TokenURL:     "https://accounts.google.com/o/oauth2/token",
		TokenCache:   oauth.CacheFile(cacheFile),
	}

	// Set up a Transport using the config.
	transport := &oauth.Transport{
		Config:    config,
		Transport: http.DefaultTransport,
	}

	// Try to pull the token from the cache; if this fails, we need to get one.
	token, err := config.TokenCache.Token()
	if err != nil {
		// Get an authorization code from the user
		authUrl := config.AuthCodeURL("state")
		log.Logf(l4g.INFO, "Go to the following link in your browser: %v\n", authUrl)

		// Read the code, and exchange it for a token.
		log.Logf(l4g.INFO, "Enter verification code: ")
		var code string
		fmt.Scanln(&code)
		token, err = transport.Exchange(code)
		if err != nil {
			l4g.Crashf("An error occurred exchanging the code: %v\n", err)
		}
		log.Logf(l4g.INFO, "Token is cached in %v\n", config.TokenCache)
	}

	transport.Token = token

	// Create a new authorized Drive client.
	driveSvc, err := drive.New(transport.Client())
	if err != nil {
		l4g.Crashf("An error occurred creating Drive client: %v\n", err)
	}

	// Get pbRestUri if we don't have it
	if pbRestUri == "" {
		pbRestUri, err = dbGetConfig(con, "PB_REST_URI")
		if err != nil {
			l4g.Crashf("Could not get pb_rest_uri from DB: %v\n", err)
		}
	}

	// Ensure we can get huntFolderId (from command-line arg, DB, or via huntFolderTitle)
	if huntFolderId == "" {
		huntFolderId, _ = dbGetConfig(con, "google_hunt_folder_id")
	}
	if huntFolderId == "" && huntFolderTitle == "" {
		// still don't have huntFolderId, and we don't have title either
		// try to get title from DB
		huntFolderTitle, _ = dbGetConfig(con, "PB_HUNT")
	} else if huntFolderId != "" && huntFolderTitle != "" {
		log.Logf(l4g.INFO, "you specified hunt_folder_title but we have hunt_folder_id so it is being ignored.")
		huntFolderTitle = ""
	}
	if huntFolderId == "" && huntFolderTitle != "" {
		// huntFolderId neither specified nor in DB, but we do have title
		// so get hunt folder ID from Google by looking it up by title
		// or create it if it does not exist
		log.Logf(l4g.INFO, "looking up google docs folder id for title %v\n", huntFolderTitle)
		huntFolderId, err = getFolderIdByTitle(driveSvc, huntFolderTitle)
		if err != nil {
			if err, ok := err.(*listError); ok {
				if err.Found > 1 {
					l4g.Crashf("more than one document matches %v\n", huntFolderTitle)
				} else if err.Found == 0 {
					log.Logf(l4g.INFO, "no hunt folder found for %v, creating it\n", huntFolderTitle)
					var cferr error
					huntFolderId, cferr = createFolder(driveSvc, huntFolderTitle)
					if cferr != nil {
						l4g.Crashf("could not create hunt folder for %v: %v\n", huntFolderTitle, cferr)
					}
					log.Logf(l4g.INFO, "hunt folder created\n")
				}
			} else {
				l4g.Crashf("an error occurred getting hunt folder ID: %v\n", err)
			}
		}
		log.Logf(l4g.INFO, "hunt_folder_id: %v\n", huntFolderId)
		// DB doesn't yet have huntFolderId, set it if we have it 
		if huntFolderId != "" {
			err = dbSetConfig(con, "google_hunt_folder_id", huntFolderId)
			if err != nil {
				l4g.Crashf("could not set hunt_folder_id in DB\n")
			}
		}
	}

	
	go startHttpControl()	

}

type listError struct {
	Query string // query string
	Found int // number of items found
}
func (nfe *listError) Error() string {
	return fmt.Sprintf("filelist query for [%v] returned %v items\n", nfe.Query, nfe.Found)
}

func dbGetConfig(dbcon *sql.DB, key string) (val string, err error) {
	var valNS sql.NullString
	err = dbcon.QueryRow("SELECT `val` FROM `config` WHERE `key` = '"+key+"'").Scan(&valNS)
	if err != nil {
		log.Logf(l4g.INFO, "dbGetConfig: SELECT unsuccessful for [key=%v]: %v", key, err)
		return
	}
	if valNS.Valid {
		val = valNS.String
	} else {
		// null string
		err = fmt.Errorf("dbGetConfig got NULL value for key %v", key)
	}
	return
}

func dbSetConfig(dbcon *sql.DB, key string, val string) (err error) {
	_, err = dbcon.Exec("REPLACE INTO `config` (`key`, `val`) VALUES (?, ?)", key, val)
	if err != nil {
		log.Logf(l4g.INFO, "dbSetConfig: INSERT unsuccessful: %v", err)
	}
	return
}

func getFolderIdByTitle(driveSvc *drive.Service, folderTitle string) (folderId string, err error) {
	folderQuery := fmt.Sprintf("title = '%v' and mimeType = 'application/vnd.google-apps.folder'", folderTitle)
	filelist, err := driveSvc.Files.List().Q(folderQuery).Do()
	if err != nil {
		log.Logf(l4g.INFO, "an error occurred searching for [%v]: %v\n", folderQuery, err)
		return
	}
	if len(filelist.Items) != 1 {
		var nfe listError
		nfe.Query = folderQuery
		nfe.Found = len(filelist.Items)
		err = &nfe
		return
	}
	folderId = filelist.Items[0].Id
	return 
}

func getChildFolderIdByTitle(driveSvc *drive.Service, folderTitle string) (parentFolderId string, folderId string, err error) {
	folderQuery := fmt.Sprintf("title = '%v' and mimeType = 'application/vnd.google-apps.folder'", folderTitle)
	filelist, err := driveSvc.Children.List(parentFolderId).Q(folderQuery).Do()
	if err != nil {
		log.Logf(l4g.INFO, "getFolderId: an error occurred searching for [%v]: %v\n", folderQuery, err)
	}
	if len(filelist.Items) != 1 {
		err = fmt.Errorf("Filelist query for [%v] returned %v items (expecting exactly 1)\n", folderQuery, len(filelist.Items)) 
	}
	folderId = filelist.Items[0].Id
	return 
}

func createFolder(driveSvc *drive.Service, folderTitle string) (folderId string, err error) {
	folder := &drive.File{
		Title:       folderTitle,
		MimeType:    "application/vnd.google-apps.folder",
//              UserPermission: *foo,
//		Description: "My test document",
	}

	folder, err = driveSvc.Files.Insert(folder).Do()
	if err != nil {
		err = fmt.Errorf("an error occurred creating the folder: %v\n", err)
	}
	folderId = folder.Id
	return 
}

type PBVersionDiff struct {
	To string
	From string
	Diff []string
}

func pbGetVersionDiff(haveVersion int64) (versionDiff *PBVersionDiff, err error) {
	pbGetVersionUri := fmt.Sprintf("%v/version/%v", pbRestUri, haveVersion)
	resp, err := httpClient.Get(pbGetVersionUri)
	if err != nil {
		log.Logf(l4g.INFO, "pbGetVersionDiff: could not get version diff at URI [%v]: %v", pbGetVersionUri, err)
		return
	}
	defer resp.Body.Close()
	
	// decode JSON
	err = json.NewDecoder(resp.Body).Decode(&versionDiff)
	if err != nil {
		log.Logf(l4g.INFO, "pbGetVersionDiff: error decoding JSON from pbrest response: %v\n", err)
		return
	}
	log.Logf(l4g.INFO, "pbGetVersionDiff: processed data from pbrest response: %+v\n", versionDiff)
	
	log.Logf(l4g.INFO, "pbGetVersionDiff: have diff from %v to %v, processing entries.\n", versionDiff.From, versionDiff.To)
	// process diff entries
	for index, entry := range versionDiff.Diff {
		log.Logf(l4g.INFO, "pbGetVersionDiff: processing [%v]th entry [%v]\n", index, entry)
		modNamePart := strings.SplitN(entry, "/", 3)
		mod := modNamePart[0]
		name := modNamePart[1]
		part := modNamePart[2]
		log.Logf(l4g.INFO, "pbGetVersionDiff: mod=[%v] name=[%v] part=[%v]\n", mod, name, part)
		if part == "" {
			switch mod {
			case "rounds": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new round name=[%v]\n", name)
				}
			case "puzzles": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new puzzle name=[%v]\n", name)
					go restGetPuzzle(name)
				}
			case "solvers": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new solver name=[%v]\n", name)
					
				}
			}
		}
	}
	
	// set new version
	version, err = strconv.ParseInt(versionDiff.To, 10, 0)
	if err != nil {
		log.Logf(l4g.INFO, "pbGetVersionDiff: could not parse version [%v] as int: %v\n", versionDiff.To, err)
	}

	log.Logf(l4g.INFO, "pbGetVersionDiff: version now %v", version)
	return
}

func startHttpControl() {
	// Start an http server for control
	http.HandleFunc("/"+httpControlPath+"/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			log.Logf(l4g.INFO, "Got POST on control port to %v\n", html.EscapeString(r.URL.Path))
			
			switch r.URL.Path {
			case "/"+httpControlPath+"/version": {
					defer r.Body.Close()
					var data BigJimmyData
					err := json.NewDecoder(r.Body).Decode(&data)
					if err != nil {
						log.Logf(l4g.INFO, "Error decoding JSON from body of POST: %v\n", err)
						w.WriteHeader(http.StatusBadRequest)
						fmt.Fprintf(w, "Error decoding JSON from body of POST: %v\n", err)
					}
					log.Logf(l4g.INFO, "Processed data from version POST: %+v\n", data)
					
					newVersion, err := strconv.ParseInt(data.Version, 10, 0)
					if err != nil {
						log.Logf(l4g.INFO, "Could not parse version as int: %v\n", err)
						w.WriteHeader(http.StatusBadRequest)
						fmt.Fprintf(w, "Could not parse version as int: %v\n", err)

					}
					
					if newVersion > version {
						// get version diff
						pbGetVersionDiff(version)
					}
					w.WriteHeader(http.StatusOK)
					fmt.Fprintf(w, "Processed version POST: %+v\n", data)

				}
			default: {
					w.WriteHeader(http.StatusNotFound)
					
					fmt.Fprintf(w, "Got POST on control port to %v\n", html.EscapeString(r.URL.Path))
				}
			}
		} else {
			log.Logf(l4g.INFO, "method %v not supported on control port (requested %v)\n", r.Method, html.EscapeString(r.URL.Path))
			w.WriteHeader(http.StatusNotImplemented)
			fmt.Fprintf(w, "method %v not supported on control port (requested %v)\n", r.Method, html.EscapeString(r.URL.Path))
		}
	})
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		log.Logf(l4g.INFO, "returning StatusNotFound (requested %v)\n", html.EscapeString(r.URL.Path))
	})

	

	log.Logf(l4g.INFO, "starting http server on port %v\n", httpControlPort)
	l4g.Crash(http.ListenAndServe(":"+httpControlPort, nil))
}
