package bigjimmybot

import (
	"code.google.com/p/goauth2/oauth"
	"code.google.com/p/google-api-go-client/drive/v2"
	"fmt"
	"net/http"
	l4g "code.google.com/p/log4go"
)

var driveSvc *drive.Service
var googleWriterDomain string

func OpenDrive(googleClientId string, googleClientSecret string, googleDomain string, cacheFile string) {
	googleWriterDomain = googleDomain
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

func CreateHunt(huntTitle string) (huntFolderId string, huntFolderUri string, err error) {
	log.Logf(l4g.TRACE, "CreateHunt(huntTitle=%v)\n", huntTitle)
	huntFolderId, huntFolderUri, err = CreateRootFile(huntTitle, "application/vnd.google-apps.folder")
	if err != nil {
		err = fmt.Errorf("CreateHunt: could not create hunt folder [%v]: %v\n", huntTitle, err)
	} else {
		err = SetDomainWriterPermissions(huntFolderId)
		if err != nil {
			err = fmt.Errorf("CreateHunt: could not set permissions for hunt folder [%v]: %v\n", huntFolderId, err)
		}
	}
	
	return 
}

func CreateRound(roundName string, huntFolderId string) (roundFolderId string, roundFolderUri string, err error) {
	log.Logf(l4g.TRACE, "CreateFolder(roundName=%v, huntFolderId=%v)\n", roundName, huntFolderId)
	roundFolderId, roundFolderUri, err = CreateFile(roundName, "application/vnd.google-apps.folder", huntFolderId)
	if err != nil {
		err = fmt.Errorf("CreateRound: could not create round folder [%v]: %v\n", roundName, err)
	} else {
		err = SetDomainWriterPermissions(roundFolderId)
		if err != nil {
			err = fmt.Errorf("CreateRound: could not set permissions for round folder [%v]: %v\n", roundFolderId, err)
		}
	}

	return 
}

func CreatePuzzle(puzzleName string, roundFolderId string) (puzzleSsId string, puzzleUri string, err error) {
	log.Logf(l4g.TRACE, "CreatePuzzle(puzzleName=%v, roundFolderId=%v)\n", puzzleName, roundFolderId)
	puzzleSsId, puzzleUri, err = CreateFile(puzzleName, "application/vnd.google-apps.spreadsheet", roundFolderId)
	if err != nil {
		err = fmt.Errorf("CreatePuzzle: could not create puzzle ss [%v]: %v\n", puzzleName, err)
	} else {
		err = SetDomainWriterPermissions(puzzleSsId)
		if err != nil {
			err = fmt.Errorf("CreatePuzzle: could not set permissions for puzzle ss [%v]: %v\n", puzzleSsId, err)
		}
	}
	
	return 
}

func CreateRootFile(title string, mimeType string) (fileId string, fileUri string, err error) {
	log.Logf(l4g.TRACE, "CreateRootFile(title=%v, mimeType=%v)\n", title, mimeType)
	file := &drive.File{
		Title:       title,
		MimeType:    mimeType,
	}

	file, err = driveSvc.Files.Insert(file).Do()
	if err != nil {
		err = fmt.Errorf("CreateRootFile: an error occurred creating file [%v] mimeType [%v]: %v\n", title, mimeType, err)
	}
	fileId = file.Id
	fileUri = file.AlternateLink

	return 
}

func CreateFile(title string, mimeType string, parentId string) (fileId string, fileUri string, err error) {
	log.Logf(l4g.TRACE, "CreateFile(title=%v, mimeType=%v, parentId=%v)\n", title, mimeType, parentId)
	file := &drive.File{
		Title:       title,
		MimeType:    mimeType,
	}
	parent := &drive.ParentReference{
		Id: parentId,
	}
	file.Parents = []*drive.ParentReference{parent}
	file, err = driveSvc.Files.Insert(file).Do()
	if err != nil {
		err = fmt.Errorf("CreateFile: an error occurred creating file [%v] mimeType [%v] parentId [%v]: %v\n", title, mimeType, parentId, err)
	} else {
		fileId = file.Id
		fileUri = file.AlternateLink
	}

	return 
}

func SetDomainWriterPermissions(fileId string) (err error) {

	if googleWriterDomain != "" {
		permission := &drive.Permission{
			Role: "writer",
			Type: "domain",
			Value: googleWriterDomain,
		}
		
		permission, err = driveSvc.Permissions.Insert(fileId, permission).Do()
		if err != nil {
			err = fmt.Errorf("setDomainWriterPermissions: an error occurred setting domain writer permissions for fileid [%v]: %v\n", fileId, err)
		}
	} else {
		log.Logf(l4g.INFO, "setDomainWriterPermissions: googleWriterDomain not set so writer permissions have not been given for fileId [%v]\n", fileId)
	}
	
	return
}

type ListError struct {
	Query string // query string
	Found int // number of items found
}
func (nfe *ListError) Error() string {
	return fmt.Sprintf("filelist query for [%v] returned %v items\n", nfe.Query, nfe.Found)
}
