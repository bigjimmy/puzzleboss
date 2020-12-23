package bigjimmybot

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
   	"strings"

	l4g "code.google.com/p/log4go"

	"golang.org/x/net/context"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/drive/v2"
	"google.golang.org/api/sheets/v4"
)

type Drive struct {
	DriveSvc *drive.Service
	SheetsSvc *sheets.Service
	GoogleWriterDomain string
}

func getClient(ctx context.Context, config *oauth2.Config, cacheFile string) *http.Client {
	tok, err := tokenFromFile(cacheFile)
	if err != nil {
		tok = getTokenFromWeb(config)
		saveToken(cacheFile, tok)
	}
	return config.Client(ctx, tok)
}

// getTokenFromWeb uses Config to request a Token.
// It returns the retrieved Token.
func getTokenFromWeb(config *oauth2.Config) *oauth2.Token {
	authURL := config.AuthCodeURL("state-token", oauth2.AccessTypeOffline)
	fmt.Printf("Go to the following link in your browser then type the "+
		"authorization code: \n%v\n", authURL)

	var code string
	if _, err := fmt.Scan(&code); err != nil {
		l4g.Crashf("Unable to read authorization code %v", err)
	}

	tok, err := config.Exchange(oauth2.NoContext, code)
	if err != nil {
		l4g.Crashf("Unable to retrieve token from web %v", err)
	}
	return tok
}

// tokenFromFile retrieves a Token from a given file path.
// It returns the retrieved Token and any read error encountered.
func tokenFromFile(file string) (*oauth2.Token, error) {
	f, err := os.Open(file)
	if err != nil {
		return nil, err
	}
	t := &oauth2.Token{}
	err = json.NewDecoder(f).Decode(t)
	defer f.Close()
	return t, err
}

// saveToken uses a file path to create a file and store the
// token in it.
func saveToken(file string, token *oauth2.Token) {
	fmt.Printf("Saving credential file to: %s\n", file)
	f, err := os.OpenFile(file, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		l4g.Crashf("Unable to cache oauth token: %v", err)
	}
	defer f.Close()
	json.NewEncoder(f).Encode(token)
}

func (d *Drive) OpenDrive(googleClientId string, googleClientSecret string, googleDomain string, cacheFile string) {
	d.GoogleWriterDomain = googleDomain
	var err error

	ctx := context.Background()

	oauthScopes := []string{
		"https://www.googleapis.com/auth/drive",
		"https://www.googleapis.com/auth/spreadsheets",
	}

	// Settings for Google authorization.
	oauthConfig := &oauth2.Config{
		ClientID:     googleClientId,
		ClientSecret: googleClientSecret,
		Endpoint:     google.Endpoint,
		RedirectURL:  "urn:ietf:wg:oauth:2.0:oob",
		Scopes:       oauthScopes,
	}

	client := getClient(ctx, oauthConfig, cacheFile)

	// Create a new authorized Drive client.
	d.DriveSvc, err = drive.New(client)
	if err != nil {
		l4g.Crashf("An error occurred creating Drive client: %v", err)
	}

	// Create a new authorized Sheets client.
	d.SheetsSvc, err = sheets.New(client)
	if err != nil {
		l4g.Crashf("An error occurred creating Sheets client: %v", err)
	}
}


func (d *Drive) GetFolderIdByTitle(folderTitle string) (folderId string, err error) {
	folderQuery := fmt.Sprintf("title = '%v' and mimeType = 'application/vnd.google-apps.folder'", folderTitle)
	filelist, err := d.DriveSvc.Files.List().Q(folderQuery).Do()
	if err != nil {
		log.Logf(l4g.ERROR, "an error occurred searching for [%v]: %v", folderQuery, err)
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

func (d *Drive) GetChildFolderIdByTitle(folderTitle string) (parentFolderId string, folderId string, err error) {
	folderQuery := fmt.Sprintf("title = '%v' and mimeType = 'application/vnd.google-apps.folder'", folderTitle)
	filelist, err := d.DriveSvc.Children.List(parentFolderId).Q(folderQuery).Do()
	if err != nil {
		log.Logf(l4g.ERROR, "getFolderId: an error occurred searching for [%v]: %v", folderQuery, err)
	}
	if len(filelist.Items) != 1 {
		err = fmt.Errorf("Filelist query for [%v] returned %v items (expecting exactly 1)", folderQuery, len(filelist.Items)) 
	}
	folderId = filelist.Items[0].Id
	return 
}

type Revision struct {
	Id string
	LastModifyingFullName string
	ModifiedDate string
}

func (d *Drive) GetLatestPuzzleRevision(puzzleId string) (revision Revision, err error) {
        // forget about listing revisions - during hunt all the changes made by users are lumped into one big merged revision
        // just retrieve the latest "head" revision and see who is the last to modify it
        rev, err := d.DriveSvc.Revisions.Get(puzzleId, "head").Do()
        if err != nil {
                log.Logf(l4g.ERROR, "GetPuzzleRevisions: an error occurred getting revisions list for puzzleId [%v]: %v", puzzleId, err)
                return
        }
        revision.Id = rev.Id
        revision.LastModifyingFullName = rev.LastModifyingUserName
        revision.ModifiedDate = rev.ModifiedDate

	return
}

// N.B. it seems we can only get lumped-together revision lists via the API: http://stackoverflow.com/questions/34955515/google-rest-api-v3-revisionslist-vs-show-more-detailed-revisions#34957303
func (d *Drive) GetNewPuzzleRevisions(puzzleId string) (revisions []Revision, err error) {
	// fields := "items/id,items/modifiedDate,items/lastModifyingUserName"

	revisionList, err := d.DriveSvc.Revisions.List(puzzleId).Do()

	if err != nil {
		log.Logf(l4g.ERROR, "GetPuzzleRevisions: an error occurred getting revisions list for puzzleId [%v]: %v", puzzleId, err)
		return nil, err
	}
	revisions = make([]Revision, 0, 100)
	for _, rev := range revisionList.Items { 
		var revision Revision
		revision.Id = rev.Id
		revision.LastModifyingFullName = rev.LastModifyingUserName
		revision.ModifiedDate = rev.ModifiedDate
		revisions = append(revisions, revision)
	}
	revisionList = nil
	return revisions, err
}

func (d *Drive) GetNewPuzzleComments(puzzleId string) (commentList *drive.CommentList, err error) {
	commentList, err = d.DriveSvc.Comments.List(puzzleId).Do()
	if err != nil {
		log.Logf(l4g.ERROR, "GetPuzzleComments: an error occurred getting comments list for puzzleId [%v]", puzzleId)
		return
	}
	
	return
}

func (d *Drive) CreateHunt(huntTitle string) (huntFolderId string, huntFolderUri string, err error) {
	log.Logf(l4g.TRACE, "CreateHunt(huntTitle=%v)", huntTitle)
	huntFolderId, huntFolderUri, err = d.CreateRootFile(huntTitle, "application/vnd.google-apps.folder")
	if err != nil {
		err = fmt.Errorf("CreateHunt: could not create hunt folder [%v]: %v", huntTitle, err)
	} else {
		err = d.SetDomainWriterPermissions(huntFolderId)
		if err != nil {
			err = fmt.Errorf("CreateHunt: could not set permissions for hunt folder [%v]: %v", huntFolderId, err)
		}
	}
	
	return 
}

func (d *Drive) CreateRound(roundName string, huntFolderId string) (roundFolderId string, roundFolderUri string, err error) {
	log.Logf(l4g.TRACE, "CreateFolder(roundName=%v, huntFolderId=%v)", roundName, huntFolderId)
	roundFolderId, roundFolderUri, err = d.CreateFile(roundName, "application/vnd.google-apps.folder", huntFolderId)
	if err != nil {
		err = fmt.Errorf("CreateRound: could not create round folder [%v]: %v", roundName, err)
	} else {
		err = d.SetDomainWriterPermissions(roundFolderId)
		if err != nil {
			err = fmt.Errorf("CreateRound: could not set permissions for round folder [%v]: %v", roundFolderId, err)
		}
	}

	return 
}

func (d *Drive) CreatePuzzle(puzzle *Puzzle, roundFolderId string) (puzzleSsId string, puzzleUri string, puzzleDlink string, err error) {
	log.Logf(l4g.TRACE, "CreatePuzzle(puzzle.Name=%v, roundFolderId=%v)", puzzle.Name, roundFolderId)
	puzzleSsId, puzzleUri, err = d.CreateFile(puzzle.Name, "application/vnd.google-apps.spreadsheet", roundFolderId)
	if err != nil {
		err = fmt.Errorf("CreatePuzzle: could not create puzzle ss [%v]: %v", puzzle.Name, err)
		return
	} else {
		err = d.SetDomainWriterPermissions(puzzleSsId)
		if err != nil {
			err = fmt.Errorf("CreatePuzzle: could not set permissions for puzzle ss [%v]: %v", puzzleSsId, err)
			return
		}
	}
	
	err = d.SetInitialPuzzleSpreadsheetContents(puzzle, puzzleSsId)
	if err != nil {
		err = fmt.Errorf("CreatePuzzle: failed to set initial puzzle spreadsheet contents for [%v]: %v", puzzle.Name, err)
		return
	}
	puzzleDlink = "<a href='"+puzzleUri+"'>DOC</a>"
	return 
}

func (d *Drive) CreateRootFile(title string, mimeType string) (fileId string, fileUri string, err error) {
	log.Logf(l4g.TRACE, "CreateRootFile(title=%v, mimeType=%v)", title, mimeType)
	file := &drive.File{
		Title:       title,
		MimeType:    mimeType,
	}

	file, err = d.DriveSvc.Files.Insert(file).Do()
	if err != nil {
		err = fmt.Errorf("CreateRootFile: an error occurred creating file [%v] mimeType [%v]: %v", title, mimeType, err)
	}
	fileId = file.Id
	fileUri = file.AlternateLink

	return 
}

func (d *Drive) CreateFile(title string, mimeType string, parentId string) (fileId string, fileUri string, err error) {
	log.Logf(l4g.TRACE, "CreateFile(title=%v, mimeType=%v, parentId=%v)", title, mimeType, parentId)
	file := &drive.File{
		Title:       title,
		MimeType:    mimeType,
	}
	parent := &drive.ParentReference{
		Id: parentId,
	}
	file.Parents = []*drive.ParentReference{parent}
	file, err = d.DriveSvc.Files.Insert(file).Do()
	if err != nil {
		err = fmt.Errorf("CreateFile: an error occurred creating file [%v] mimeType [%v] parentId [%v]: %v", title, mimeType, parentId, err)
	} else {
		fileId = file.Id
		fileUri = strings.Replace(file.AlternateLink,"stormynight.org","wind-up-birds.org",-1)
	}

	return 
}

func (d *Drive) SetDomainWriterPermissions(fileId string) (err error) {
	if d.GoogleWriterDomain != "" {
		permission := &drive.Permission{
			Role: "writer",
			Type: "domain",
			Value: d.GoogleWriterDomain,
		}
		
		permission, err = d.DriveSvc.Permissions.Insert(fileId, permission).Do()
		if err != nil {
			err = fmt.Errorf("setDomainWriterPermissions: an error occurred setting domain writer permissions for fileid [%v]: %v", fileId, err)
		}
	} else {
		log.Logf(l4g.INFO, "setDomainWriterPermissions: d.GoogleWriterDomain not set so writer permissions have not been given for fileId [%v]", fileId)
	}

	return
}

func (d *Drive) SetInitialPuzzleSpreadsheetContents(puzzle *Puzzle, spreadsheetId string) (err error) {
	log.Logf(l4g.TRACE, "SetInitialPuzzleSpreadsheetContents: retrieving spreadsheetId [%v] for puzzle %+v", spreadsheetId, puzzle)
	var spreadsheet *sheets.Spreadsheet
	spreadsheet, err = d.SheetsSvc.Spreadsheets.Get(spreadsheetId).Do()
	log.Logf(l4g.TRACE, "SetInitialPuzzleSpreadsheetContents: done retrieving spreadsheet=[%#v] err=[%#v]", spreadsheet, err)
	if err != nil {
		err = fmt.Errorf("SetInitialPuzzleSpreadsheetContents: failed to get spreadsheetId [%v] for puzzle [%v]: %v", spreadsheetId, puzzle.Name, err)
		return err
	}
	log.Logf(l4g.TRACE, "SetInitialPuzzleSpreadsheetContents: have spreadsheet: %#v with %d sheets", spreadsheet, len(spreadsheet.Sheets))
	currTitle := spreadsheet.Sheets[0].Properties.Title
	if currTitle == "Sheet1" {
		// only modify spreadsheet if it has not been edited yet
		log.Logf(l4g.INFO, "SetInitialPuzzleSpreadsheetContents: setting initial contents on spreadsheet [%v] for puzzle [%v]", spreadsheetId, puzzle.Name)

		var batchResponse *sheets.BatchUpdateSpreadsheetResponse
	        addSheetRequests := []*sheets.Request{
			// Create new sheet for metadata
			&sheets.Request{
				AddSheet: &sheets.AddSheetRequest{
					Properties: &sheets.SheetProperties{
						Title: fmt.Sprintf("%s metadata", puzzle.Name),
						GridProperties: &sheets.GridProperties{
							RowCount: 7,
							ColumnCount: 2,
						},
						Index: 0,
						SheetId: 1,
					},
				},
			},
		}
		batchResponse, err = d.SheetsSvc.Spreadsheets.BatchUpdate(spreadsheetId, &sheets.BatchUpdateSpreadsheetRequest{Requests: addSheetRequests}).Do()
		if err != nil {
			err = fmt.Errorf("SetInitialPuzzleSpreadsheetContents: an error occured adding sheet to spreadsheetId [%v] for puzzle [%v]: %v", spreadsheetId, puzzle.Name, err)
			return err
		}
		log.Logf(l4g.TRACE, "SetInitialPuzzleSpreadsheetContents: [0]AddSheet reply: %#v", batchResponse.Replies[0].AddSheet)

	        updateSheetRequests := []*sheets.Request{
			// Relabel existing sheet as "Work", set grid to 100x26, and move to index 2
			&sheets.Request{
				UpdateSheetProperties: &sheets.UpdateSheetPropertiesRequest{
					Properties: &sheets.SheetProperties{
						SheetId: spreadsheet.Sheets[0].Properties.SheetId,
						Title: fmt.Sprintf("Work on %s", puzzle.Name),
						GridProperties: &sheets.GridProperties{
							RowCount: 100,
							ColumnCount: 26,
						},
						Index: 2,
					},
					Fields: "title,gridProperties.rowCount,gridProperties.columnCount,index",
				},
			},
		}
		batchResponse, err = d.SheetsSvc.Spreadsheets.BatchUpdate(spreadsheetId, &sheets.BatchUpdateSpreadsheetRequest{Requests: updateSheetRequests}).Do()
		if err != nil {
			err = fmt.Errorf("SetInitialPuzzleSpreadsheetContents: an error occured batch updating work sheet on spreadsheetId [%v] for puzzle [%v]: %v", spreadsheetId, puzzle.Name, err)
			return err
		}

	        dimensionRequests := []*sheets.Request{
			&sheets.Request{
				UpdateDimensionProperties: &sheets.UpdateDimensionPropertiesRequest{
					Properties: &sheets.DimensionProperties{
						PixelSize: 150,
					},
					Range: &sheets.DimensionRange{
						SheetId: 1,
						Dimension: "COLUMNS",
						StartIndex: 0,
						EndIndex: 1,
					},
					Fields: "pixelSize",
				},
			},
			&sheets.Request{
				UpdateDimensionProperties: &sheets.UpdateDimensionPropertiesRequest{
					Properties: &sheets.DimensionProperties{
						PixelSize: 1000,
					},
					Range: &sheets.DimensionRange{
						SheetId: 1,
						Dimension: "COLUMNS",
						StartIndex: 1,
						EndIndex: 2,
					},
					Fields: "pixelSize",
				},
			},
		}
		batchResponse, err = d.SheetsSvc.Spreadsheets.BatchUpdate(spreadsheetId, &sheets.BatchUpdateSpreadsheetRequest{Requests: dimensionRequests}).Do()
		if err != nil {
			err = fmt.Errorf("SetInitialPuzzleSpreadsheetContents: an error occured dimensioning columns on spreadsheetId [%v] for puzzle [%v]: %v", spreadsheetId, puzzle.Name, err)
			return err
		}

		valueRange := fmt.Sprintf("%s metadata!A1:B9", puzzle.Name)
		values := [][]interface{}{
			{"Round:",		puzzle.Round},
			{"Puzzle:",		puzzle.Name},
			{"Actual Puzzle URL:",	puzzle.Uri},
			{"Slack Channel:", "#" + puzzle.Slack_channel_name},
			{"Slack Channel Link:", puzzle.Slack_channel_link},
			{},
			{"No spoilers on this worksheet, please!"},
			{"Please use a different sheet (see tabs below) for work and create additional sheets as needed to pursue different ideas (or independent solves)"},
		}
		rbValues := &sheets.BatchUpdateValuesRequest{
			ValueInputOption: "USER_ENTERED",
		}
		rbValues.Data = append(rbValues.Data, &sheets.ValueRange{
			MajorDimension: "ROWS",
			Range:  valueRange,
			Values: values,
		})
		log.Logf(l4g.TRACE, "SetInitialPuzzleSpreadsheetContents: calling Values.BatchUpdate with rbValues: %+v", rbValues)
		var rbValuesResp *sheets.BatchUpdateValuesResponse
		rbValuesResp, err = d.SheetsSvc.Spreadsheets.Values.BatchUpdate(spreadsheetId, rbValues).Do()
		log.Logf(l4g.TRACE, "SetInitialPuzzleSpreadsheetContents: response from batch update on values: %+v", rbValuesResp)
		if err != nil {
			err = fmt.Errorf("SetInitialPuzzleSpreadsheetContents: an error occured batch updating values on spreadsheetId [%v] for puzzle [%v]: %v", spreadsheetId, puzzle.Name, err)
			return err
		}
		log.Logf(l4g.INFO, "SetInitialPuzzleSpreadsheetContents: finished setting initial contents on spreadsheet [%v] for puzzle [%v]", spreadsheetId, puzzle.Name)
	} else {
		log.Logf(l4g.INFO, "SetInitialPuzzleSpreadsheetContents: spreadsheet [%v] for puzzle [%v] has apparently already been edited - sheet[0] title was %s", spreadsheetId, puzzle.Name, currTitle)
	}
	return
}

type ListError struct {
	Query string // query string
	Found int // number of items found
}
func (nfe *ListError) Error() string {
	return fmt.Sprintf("filelist query for [%v] returned %v items", nfe.Query, nfe.Found)
}

