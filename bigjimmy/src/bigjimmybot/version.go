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

func PbGetVersionDiff(haveVersion int64) (versionDiff *PBVersionDiff, err error) {
	pbGetVersionUri := fmt.Sprintf("%v/version/%v", pbRestUri, haveVersion)
	resp, err := httpClient.Get(pbGetVersionUri)
	if err != nil {
		log.Logf(l4g.ERROR, "pbGetVersionDiff: could not get version diff at URI [%v]: %v", pbGetVersionUri, err)
		return
	}
	defer resp.Body.Close()
	
	// decode JSON
	err = json.NewDecoder(resp.Body).Decode(&versionDiff)
	if err != nil {
		log.Logf(l4g.ERROR, "pbGetVersionDiff: error decoding JSON from pbrest response: %v\n", err)
		return
	}
	log.Logf(l4g.DEBUG, "pbGetVersionDiff: processed data from pbrest response: %+v\n", versionDiff)
	
	log.Logf(l4g.DEBUG, "pbGetVersionDiff: have diff from %v to %v, processing entries.\n", versionDiff.From, versionDiff.To)
	roundsAddedP := false
	puzzlesAddedP := false
	solversAddedP := false
	// process diff entries
	for index, entry := range versionDiff.Diff {
		log.Logf(l4g.DEBUG, "pbGetVersionDiff: processing [%v]th entry [%v]\n", index, entry)
		modNamePart := strings.SplitN(entry, "/", 3)
		mod := modNamePart[0]
		name := modNamePart[1]
		part := modNamePart[2]
		log.Logf(l4g.DEBUG, "pbGetVersionDiff: mod=[%v] name=[%v] part=[%v]\n", mod, name, part)
		if part == "" {
			switch mod {
			case "rounds": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new round name=[%v]\n", name)
					RoundCount++
					roundsAddedP = true
					go RestGetRound(name)
				}
			case "puzzles": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new puzzle name=[%v]\n", name)
					PuzzleCount++
					puzzlesAddedP = true
					go RestGetPuzzle(name)
				}
			case "solvers": {
					log.Logf(l4g.INFO, "pbGetVersionDiff: have new solver name=[%v]\n", name)
					SolverCount++
					solversAddedP = true
					go RestGetSolver(name)
				}
			}
		}
	}
	
	// set new version
	Version, err = strconv.ParseInt(versionDiff.To, 10, 0)
	if err != nil {
		log.Logf(l4g.ERROR, "pbGetVersionDiff: could not parse version [%v] as int: %v\n", versionDiff.To, err)
	}

	// wait for everything to arrive
	if roundsAddedP {
		//log.Logf(l4g.INFO, "pbGetVersionDiff: waiting for all added rounds to arrive")
		//<- restGetRoundsDone
	}
	if puzzlesAddedP {
		log.Logf(l4g.INFO, "pbGetVersionDiff: waiting for all added puzzles to arrive")
		<- restGetPuzzlesDone
	}
	if solversAddedP {
		//log.Logf(l4g.INFO, "pbGetVersionDiff: waiting for all added solvers to arrive")

		//<- restGetSolversDone
	}
	
	// diff processing complete
	log.Logf(l4g.INFO, "pbGetVersionDiff: Version now %v", Version)

	//log.Logf(l4g.DEBUG, "pbGetVersionDiff: have rounds %+v", rounds)
	log.Logf(l4g.DEBUG, "pbGetVersionDiff: have puzzles %+v", puzzles)
	//log.Logf(l4g.DEBUG, "pbGetVersionDiff: have solvers %+v", solvers)
	
	return
}

