package bigjimmybot

import (
	"strings"
	"fmt"
	"encoding/json"
	"strconv"
	l4g "code.google.com/p/log4go"
)

type PBVersionDiff struct {
	To string
	From string
	Diff []string
}

var RoundCount int = 0
var PuzzleCount int = 0
var SolverCount int = 0
var Version int64 = 0

var pbGetVersionDiffLimiter chan int
var versionChan chan int64

func init() {
	pbGetVersionDiffLimiter = make(chan int, 10) // only ten PbGetVersionDiff allowed to run at a time
	versionChan = make(chan int64, 500) // up to 500 versions can queue up for processing before we start blocking on the ControlServer

	// get versions from versionChan and process them using PbGetVersionDiff
	go func(){
		for true {
			log.Logf(l4g.TRACE, "versionChan listener: waiting for new version")
			version := <-versionChan // this will block waiting for new versions
			log.Logf(l4g.INFO, "versionChan listener: got new version %v", version)
			Version = version
			PbGetVersionDiff(version)
		}
	}()
}

func PbGetVersionDiff(version int64) (versionDiff *PBVersionDiff, err error) {
	log.Logf(l4g.TRACE, "PbGetVersionDiff(version=%v)", version)
	pbGetVersionUri := fmt.Sprintf("%v/version/%v/%v", pbRestUri, version-1, version)
	versionDiff, err = pbGetVersionDiff(pbGetVersionUri)
	return
}

func PbGetInitialVersionDiff() (versionDiff *PBVersionDiff, err error) {
	pbGetVersionUri := fmt.Sprintf("%v/version/%v", pbRestUri, 0)
	versionDiff, err = pbGetVersionDiff(pbGetVersionUri)
	return
}

func pbGetVersionDiff(pbGetVersionUri string) (versionDiff *PBVersionDiff, err error) {
	log.Logf(l4g.TRACE, "pbGetVersionDiff(pbGetVersionUri=%v)", pbGetVersionUri)
	pbGetVersionDiffLimiter<-1 // put a token in the limiting channel (this will block if buffer is full)
	defer func() {
		log.Logf(l4g.DEBUG, "pbGetVersionDiff: releasing token for pbGetVersionUri=%v", pbGetVersionUri)
		<-pbGetVersionDiffLimiter // release a token from the limiting channel
	}()

	resp, err := httpClient.Get(pbGetVersionUri)
	if err != nil {
		log.Logf(l4g.ERROR, "pbGetVersionDiff: could not get version diff at URI [%v]: %v", pbGetVersionUri, err)
		return
	}
	defer resp.Body.Close()
	
	// decode JSON
	err = json.NewDecoder(resp.Body).Decode(&versionDiff)
	if err != nil {
		log.Logf(l4g.ERROR, "pbGetVersionDiff: error decoding JSON from pbrest response: %v", err)
		return
	}
	log.Logf(l4g.DEBUG, "pbGetVersionDiff: processed data from pbrest response: %+v", versionDiff)
	
	// set new version (because we have the diff and are going to process it, so eventually this will be our version)
	Version, err = strconv.ParseInt(versionDiff.To, 10, 0)
	if err != nil {
		log.Logf(l4g.ERROR, "pbGetVersionDiff: could not parse version [%v] as int: %v", versionDiff.To, err)
	}

	log.Logf(l4g.DEBUG, "pbGetVersionDiff: have diff from %v to %v, processing entries.", versionDiff.From, versionDiff.To)
	roundsAddedP := false
	puzzlesAddedP := false
	solversAddedP := false
	// process diff entries
	for index, entry := range versionDiff.Diff {
		log.Logf(l4g.DEBUG, "pbGetVersionDiff: processing [%v]th entry [%v]", index, entry)
		modNamePart := strings.SplitN(entry, "/", 3)
		mod := modNamePart[0]
		name := modNamePart[1]
		part := modNamePart[2]
		log.Logf(l4g.DEBUG, "processSingleDiffEntry: mod=[%v] name=[%v] part=[%v]", mod, name, part)
		if mod != "" && name != "" && part == "" { // addition of a puzzle, round, solver, or location
			switch mod {
			case "rounds": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new round name=[%v]", name)
					RoundCount++
					roundsAddedP = true
					go RestGetRound(name)
				}
			case "puzzles": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new puzzle name=[%v]", name)
					PuzzleCount++
					puzzlesAddedP = true
					go RestGetPuzzle(name)
				}
			case "solvers": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new solver name=[%v]", name)
					SolverCount++
					solversAddedP = true
					go RestGetSolver(name)
				}
			}
		}
	}
	
	// wait for everything to arrive
	if roundsAddedP {
		log.Logf(l4g.INFO, "pbGetVersionDiff: waiting for all added rounds to arrive")
		<- restGetRoundsDone
	}
	if puzzlesAddedP {
		log.Logf(l4g.INFO, "pbGetVersionDiff: waiting for all added puzzles to arrive")
		<- restGetPuzzlesDone
	}
	if solversAddedP {
		log.Logf(l4g.INFO, "pbGetVersionDiff: waiting for all added solvers to arrive")
		<- restGetSolversDone
	}
	
	// diff processing complete
	log.Logf(l4g.INFO, "pbGetVersionDiff: Version complete at version %v", Version)

	log.Logf(l4g.DEBUG, "pbGetVersionDiff: have rounds %+v", rounds)
	log.Logf(l4g.DEBUG, "pbGetVersionDiff: have puzzles %+v", puzzles)
	log.Logf(l4g.DEBUG, "pbGetVersionDiff: have solvers %+v", solvers)
	
	return
}

