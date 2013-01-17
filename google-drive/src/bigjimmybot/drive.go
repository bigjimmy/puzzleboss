package bigjimmybot

import (
	"code.google.com/p/goauth2/oauth"
	"code.google.com/p/google-api-go-client/drive/v2"
	"fmt"
	"net/http"
	l4g "code.google.com/p/log4go"
)

var driveSvc *drive.Service

func OpenDrive(googleClientId string, googleClientSecret string, cacheFile string) {
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
	driveSvc, err = drive.New(transport.Client())
	if err != nil {
		l4g.Crashf("An error occurred creating Drive client: %v\n", err)
	}
}


func GetFolderIdByTitle(folderTitle string) (folderId string, err error) {
	folderQuery := fmt.Sprintf("title = '%v' and mimeType = 'application/vnd.google-apps.folder'", folderTitle)
	filelist, err := driveSvc.Files.List().Q(folderQuery).Do()
	if err != nil {
		log.Logf(l4g.ERROR, "an error occurred searching for [%v]: %v\n", folderQuery, err)
		return
	}
	if len(filelist.Items) != 1 {
		var nfe ListError
		nfe.Query = folderQuery
		nfe.Found = len(filelist.Items)
		err = &nfe
		return
	}
	folderId = filelist.Items[0].Id
	return 
}

func GetChildFolderIdByTitle(folderTitle string) (parentFolderId string, folderId string, err error) {
	folderQuery := fmt.Sprintf("title = '%v' and mimeType = 'application/vnd.google-apps.folder'", folderTitle)
	filelist, err := driveSvc.Children.List(parentFolderId).Q(folderQuery).Do()
	if err != nil {
		log.Logf(l4g.ERROR, "getFolderId: an error occurred searching for [%v]: %v\n", folderQuery, err)
	}
	if len(filelist.Items) != 1 {
		err = fmt.Errorf("Filelist query for [%v] returned %v items (expecting exactly 1)\n", folderQuery, len(filelist.Items)) 
	}
	folderId = filelist.Items[0].Id
	return 
}

func CreateFolder(folderTitle string) (folderId string, err error) {
	folder := &drive.File{
		Title:       folderTitle,
		MimeType:    "application/vnd.google-apps.folder",
//              UserPermission: *foo,
	}

	folder, err = driveSvc.Files.Insert(folder).Do()
	if err != nil {
		err = fmt.Errorf("an error occurred creating the folder: %v\n", err)
	}
	folderId = folder.Id
	return 
}

type ListError struct {
	Query string // query string
	Found int // number of items found
}
func (nfe *ListError) Error() string {
	return fmt.Sprintf("filelist query for [%v] returned %v items\n", nfe.Query, nfe.Found)
}
