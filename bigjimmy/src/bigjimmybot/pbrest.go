package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"github.com/bigjimmy/restclient"
)

// todo update restclient/napping to v3
var client *restclient.Client

func init() {
	client = restclient.New()
}

type PartPost struct {
	Data string `json:"data"`
}

type PostResult struct {
	Status string
	Error string
	Id string
	Part string
	Data string
}

func PbRestPost(path string, data interface{}) {
	log.Logf(l4g.TRACE, "PbRestPost(path=%v)", path)
	httpRestReqLimiter<-1 // put a token in the limiting channel (this will block if buffer is full)
	log.Logf(l4g.DEBUG, "PbRestPost: putting a token in the limiting channel for POST to %v", path)
	defer func() {
		log.Logf(l4g.DEBUG, "PbRestPost: releasing token from POST to %v", path)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()
	
	log.Logf(l4g.DEBUG, "PbRestPost: preparing POST to %v", path)
	uri := pbRestUri+"/"+path
	//client := restclient.New()
	req := restclient.RestRequest{
		Url:    uri,
		Method: restclient.POST,
		Result: new(PostResult),
		Data:   data,
	}
	log.Logf(l4g.DEBUG, "PbRestPost: sending POST to [%v]", uri)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "PbRestPost: error %v", err)
		// TODO: do something... retry?
	}
	log.Logf(l4g.DEBUG, "PbRestPost: received response for POST to [%v]", uri)
	if status == 200 {
		// HTTP status ok
		if req.Result.(*PostResult).Status == "ok" {
			//JSON status:ok message
		} else {
			log.Logf(l4g.ERROR, "PbRestPost: HTTP status 200 OK but data payload was not {status:ok}. got [%v].", req.RawText)
			// TODO: do something?
		}
	} else {
		log.Logf(l4g.ERROR, "PbRestPost: got status %v for [%v]", status, uri)
		// TODO: do something... retry, depending on what status was?
	}
}

func RestGetRound(name string, roundChan chan *Round) {
	log.Logf(l4g.TRACE, "RestGetRound(name=%v)", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetRound: releasing token from fetching %v", name)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()

	log.Logf(l4g.DEBUG, "RestGetRound: preparing request for %v", name)
	//client := restclient.New()
	req := restclient.RestRequest{
		Url:    pbRestUri+"/rounds/"+name,
		Method: restclient.GET,
		Result: new(Round),
	}
	log.Logf(l4g.DEBUG, "RestGetRound: sending request for %v", name)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "RestGetRound: error %v", err)
		// TODO: do something... retry?
		l4g.Crashf("RestGetRound: could not get round [%v] - bailing out", name)
	}
	log.Logf(l4g.DEBUG, "RestGetRound: received response for %v", name)
	if status == 200 {
		// send result on roundChan
		log.Logf(l4g.DEBUG, "RestGetRound: sending round on roundChan for %v", name)
		roundChan<-req.Result.(*Round)
	} else {
		log.Logf(l4g.ERROR, "RestGetRound: got status %v", status)
		// TODO: do something... retry?
		l4g.Crashf("RestGetRound: could not get round [%v] - bailing out", name)
	}
}



func RestGetPuzzle(name string, puzzleChan chan *Puzzle) {
	log.Logf(l4g.DEBUG, "RestGetPuzzle: requesting token to fetch %v", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetPuzzle: releasing token from fetching %v", name)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()

	log.Logf(l4g.DEBUG, "RestGetPuzzle: preparing request for %v", name)
	//client := restclient.New()
	req := restclient.RestRequest{
		Url:    pbRestUri+"/puzzles/"+name,
		Method: restclient.GET,
		Result: new(Puzzle),
	}
	log.Logf(l4g.DEBUG, "RestGetPuzzle: sending request for %v", name)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "RestGetPuzzle: error %v", err)
		// TODO: do something... retry?
		l4g.Crashf("RestGetPuzzle: could not get puzzle [%v] - bailing out", name)
	}
	log.Logf(l4g.DEBUG, "RestGetPuzzle: received response for %v", name)
	if status == 200 {
		// send result on puzzleChan
		log.Logf(l4g.DEBUG, "RestGetPuzzle: sending puzzle on puzzleChan for %v", name)
		puzzleChan<-req.Result.(*Puzzle)
	} else {
		log.Logf(l4g.ERROR, "RestGetPuzzle: got status %v", status)
		// TODO: do something... retry?
		l4g.Crashf("RestGetPuzzle: could not get puzzle [%v] - bailing out", name)
	}
}

func RestGetSolverSync(name string) (solver *Solver) {
        mySolverChan := make(chan *Solver)
	go RestGetSolver(name, mySolverChan)
	solver = <-mySolverChan
	close(mySolverChan)
	return
}

func RestGetSolver(name string, solverChan chan *Solver) {
	log.Logf(l4g.DEBUG, "RestGetSolver: requesting token to fetch %v", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetSolver: releasing token from fetching %v", name)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()

	log.Logf(l4g.DEBUG, "RestGetSolver: preparing request for %v", name)
	//client := restclient.New()
	req := restclient.RestRequest{
		Url:    pbRestUri+"/solvers/"+name,
		Method: restclient.GET,
		Result: new(Solver),
	}
	log.Logf(l4g.DEBUG, "RestGetSolver: sending request for %v", name)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "RestGetSolver: error %v", err)
		// TODO: do something... retry?
		// l4g.Crashf("RestGetSolver: could not get solver [%v] - bailing out", name)
	} else {
		log.Logf(l4g.DEBUG, "RestGetSolver: received response for %v", name)
	}
	if status == 200 {
		// send result on solverChan
		log.Logf(l4g.DEBUG, "RestGetSolver: sending solver on solverChan for %v", name)
		solverChan<-req.Result.(*Solver)
	} else {
		log.Logf(l4g.ERROR, "RestGetSolver: got status %v", status)
		// TODO: do something... retry?
		// l4g.Crashf("RestGetSolver: could not get solver [%v] - bailing out", name)
	}
}

