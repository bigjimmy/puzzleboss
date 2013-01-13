package main

import (
	"code.google.com/p/goauth2/oauth"
	"code.google.com/p/google-api-go-client/drive/v2"
	"flag"
	"fmt"
	"log"
	"net/http"
	"html"
	"database/sql"
	_ "github.com/Go-SQL-Driver/MySQL"
)

// Configure command-line args
var httpControlPort, httpControlPath string
var googleClientId, googleClientSecret, cacheFile string
var dbProtocol, dbHost, dbPort, dbName, dbUser, dbPassword string
var huntFolderTitle, huntFolderId string
func init() {

	// HTTP control server 
	flag.StringVar(&httpControlPort, "http_port", "8080", "HTTP control port")
	flag.StringVar(&httpControlPath, "http_path", "bigjimmy", "HTTP control path")
	
	// authentication 
	flag.StringVar(&googleClientId, "id", "", "Client ID")
	flag.StringVar(&googleClientSecret, "secret", "", "Client Secret")
	flag.StringVar(&cacheFile, "cache", "bigjimmy-oauth-cache.json", "Token cache file")
	
	// database
	flag.StringVar(&dbProtocol, "dbprotocol", "tcp", "Database protocol")
	flag.StringVar(&dbHost, "dbhost", "localhost", "Database host")
	flag.StringVar(&dbPort, "dbport", "3306", "Database port")
	flag.StringVar(&dbName, "dbname", "puzzlebitch", "Database name")
	flag.StringVar(&dbUser, "dbuser", "", "Database user")
	flag.StringVar(&dbPassword, "dbpassword", "", "Database password")

	// hunt config (optional, will be read from DB)
	flag.StringVar(&huntFolderTitle, "hunt_title", "", "Hunt Folder Title")
	flag.StringVar(&huntFolderId, "hunt_drive_id", "", "Hunt Folder Drive ID")
}

const usageMsg = `
To obtain a request token you must specify both -id and -secret after which 
an auth token will be stored in the -cache file. 

You can assign or lookup a client ID from the Google APIs console: https://code.google.com/apis/console/ under the API access tab.
`

// Uploads a file to Google Drive
func main() {
	flag.Parse()
	
	// Connect to database
	mysqlDsn := dbUser+":"+dbPassword+"@"+dbProtocol+"("+dbHost+":"+dbPort+")/"+dbName
	con, err := sql.Open("mysql", mysqlDsn)
	if err != nil {
		log.Fatalf("could not connect to mysql database with DSN %v: %v\n", mysqlDsn, err)
	}
	defer con.Close()

	// Start an http server for control
	http.HandleFunc("/"+httpControlPath, func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			fmt.Fprintf(w, "Got POST on control port to %v\n", html.EscapeString(r.URL.Path))
		} else {
			fmt.Fprintf(w, "method %v not supported on control port (requested %v)\n", r.Method, html.EscapeString(r.URL.Path))
		}
	})
	log.Printf("starting http server on port %v\n", httpControlPort)
	log.Fatal(http.ListenAndServe(":"+httpControlPort, nil))

	// Ensure we have googleClientId and googleClientSecret (from command-line args or DB)
	if googleClientId == "" {
		googleClientId, _ = dbGetConfig(con, "google_client_id")
	}
	if googleClientSecret == "" {
		googleClientSecret, _ = dbGetConfig(con, "google_client_secret")
	}
	if googleClientId == "" || googleClientSecret == "" {
		log.Printf("Please specify -id and -secret\n")
		flag.Usage()
		log.Fatalf(usageMsg)
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
		log.Printf("Go to the following link in your browser: %v\n", authUrl)

		// Read the code, and exchange it for a token.
		log.Printf("Enter verification code: ")
		var code string
		fmt.Scanln(&code)
		token, err = transport.Exchange(code)
		if err != nil {
			log.Fatalf("An error occurred exchanging the code: %v\n", err)
		}
		log.Printf("Token is cached in %v\n", config.TokenCache)
	}

	transport.Token = token

	// Create a new authorized Drive client.
	driveSvc, err := drive.New(transport.Client())
	if err != nil {
		log.Fatalf("An error occurred creating Drive client: %v\n", err)
	}


	// Ensure we can get huntFolderId (from command-line arg, DB, or via huntFolderTitle)
	if huntFolderId == "" {
		huntFolderId, _ = dbGetConfig(con, "hunt_folder_id")
	}
	if huntFolderId != "" && huntFolderTitle != "" {
		log.Printf("you specified hunt_folder_title but we have hunt_folder_id so it is being ignored.")
		huntFolderTitle = ""
	}
	if huntFolderId == "" && huntFolderTitle != "" {
		// huntFolderId neither specified nor in DB, but we do have title
		// so get hunt folder ID from Google by looking it up by title
		// or create it if it does not exist
		huntFolderId, err = getFolderIdByTitle(driveSvc, huntFolderTitle)
		if err != nil {
			if err, ok := err.(*listError); ok {
				if err.Found > 1 {
					log.Fatalf("more than one document matches %v\n", huntFolderTitle)
				} else if err.Found == 0 {
					log.Printf("no hunt folder found for %v, creating it\n", huntFolderTitle)
					var cferr error
					huntFolderId, cferr = createFolder(driveSvc, huntFolderTitle)
					if cferr != nil {
						log.Fatalf("could not create hunt folder for %v: %v\n", huntFolderTitle, cferr)
					}
					log.Printf("hunt folder created\n")
				}
			} else {
				log.Fatalf("an error occurred getting hunt folder ID: %v\n", err)
			}
		}
		log.Printf("hunt_folder_id: %v\n", huntFolderId)
		// DB doesn't yet have huntFolderId, set it if we have it 
		if huntFolderId != "" {
			err = dbSetConfig(con, "hunt_folder_id")
			if err != nil {
				log.Fatalf("could not set hunt_folder_id in DB\n")
			}
		}
	}

	
	// 
}

type listError struct {
	Query string // query string
	Found int // number of items found
}
func (nfe *listError) Error() string {
	return fmt.Sprintf("filelist query for [%v] returned %v items\n", nfe.Query, nfe.Found)
}

func dbGetConfig(dbcon *sql.DB, key string) (huntFolderId string, err error) {
	var huntFolderIdNS sql.NullString
	err = dbcon.QueryRow("SELECT `val` FROM `config` WHERE `key` = '"+key+"'").Scan(&huntFolderIdNS)
	if err != nil {
		log.Printf("dbGetConfig: SELECT unsuccessful: %v", err)
		return
	}
	if huntFolderIdNS.Valid {
		huntFolderId = huntFolderIdNS.String
	}
	return
}

func dbSetConfig(dbcon *sql.DB, key string) (err error) {
	_, err = dbcon.Exec("INSERT INTO `config` (`key`, `val`) VALUES (?, ?)", key, huntFolderId)
	if err != nil {
		log.Printf("dbSetConfig: INSERT unsuccessful: %v", err)
	}
	return
}

func getFolderIdByTitle(driveSvc *drive.Service, folderTitle string) (folderId string, err error) {
	folderQuery := fmt.Sprintf("title = '%v' and mimeType = 'application/vnd.google-apps.folder'", folderTitle)
	filelist, err := driveSvc.Files.List().Q(folderQuery).Do();
	if err != nil {
		log.Printf("an error occurred searching for [%v]: %v\n", folderQuery, err)
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
	filelist, err := driveSvc.Children.List(parentFolderId).Q(folderQuery).Do();
	if err != nil {
		log.Printf("getFolderId: an error occurred searching for [%v]: %v\n", folderQuery, err)
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

