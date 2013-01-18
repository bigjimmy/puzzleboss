package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"github.com/jmcvetta/restclient"
)

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
	log.Logf(l4g.TRACE, "PbRestPost(path=%v)\n", path)
	httpRestReqLimiter<-1 // put a token in the limiting channel (this will block if buffer is full)
	log.Logf(l4g.DEBUG, "PbRestPost: putting a token in the limiting channel for POST to %v\n", path)
	defer func() {
		log.Logf(l4g.DEBUG, "PbRestPost: releasing token from POST to %v\n", path)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()
	
	log.Logf(l4g.DEBUG, "PbRestPost: preparing POST to %v\n", path)
	uri := pbRestUri+"/"+path
	client := restclient.New()
	req := restclient.RestRequest{
		Url:    uri,
		Method: restclient.POST,
		Result: new(PostResult),
		Data:   data,
	}
	log.Logf(l4g.DEBUG, "PbRestPost: sending POST to [%v]\n", uri)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "PbRestPost: error %v\n", err)
		// TODO: do something... retry?
	}
	log.Logf(l4g.DEBUG, "PbRestPost: received response for POST to [%v]\n", uri)
	if status == 200 {
		// HTTP status ok
		if req.Result.(*PostResult).Status == "ok" {
			//JSON status:ok message
		} else {
			log.Logf(l4g.ERROR, "PbRestPost: HTTP status 200 OK but data payload was not {status:ok}. got [%v].\n", req.RawText)
			// TODO: do something?
		}
	} else {
		log.Logf(l4g.ERROR, "PbRestPost: got status %v for [%v]\n", status, uri)
		// TODO: do something... retry, depending on what status was?
	}
}

func RestGetRound(name string) {
	log.Logf(l4g.TRACE, "RestGetRound(name=%v)\n", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetRound: releasing token from fetching %v\n", name)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()

	log.Logf(l4g.DEBUG, "RestGetRound: preparing request for %v\n", name)
	client := restclient.New()
	req := restclient.RestRequest{
		Url:    pbRestUri+"/rounds/"+name,
		Method: restclient.GET,
		Result: new(Round),
	}
	log.Logf(l4g.DEBUG, "RestGetRound: sending request for %v\n", name)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "RestGetRound: error %v\n", err)
		// TODO: do something... retry?
		l4g.Crashf("RestGetRound: could not get round [%v] - bailing out\n", name)
	}
	log.Logf(l4g.DEBUG, "RestGetRound: received response for %v\n", name)
	if status == 200 {
		// send result on roundChan
		log.Logf(l4g.DEBUG, "RestGetRound: sending round on roundChan for %v\n", name)
		roundChan<-req.Result.(*Round)
	} else {
		log.Logf(l4g.ERROR, "RestGetRound: got status %v\n", status)
		// TODO: do something... retry?
		l4g.Crashf("RestGetRound: could not get round [%v] - bailing out\n", name)
	}
}



func RestGetPuzzle(name string) {
	log.Logf(l4g.DEBUG, "RestGetPuzzle: requesting token to fetch %v", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetPuzzle: releasing token from fetching %v", name)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()

	log.Logf(l4g.DEBUG, "RestGetPuzzle: preparing request for %v", name)
	client := restclient.New()
	req := restclient.RestRequest{
		Url:    pbRestUri+"/puzzles/"+name,
		Method: restclient.GET,
		Result: new(Puzzle),
	}
	log.Logf(l4g.DEBUG, "RestGetPuzzle: sending request for %v", name)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "RestGetPuzzle: error %v\n", err)
		// TODO: do something... retry?
		l4g.Crashf("RestGetPuzzle: could not get puzzle [%v] - bailing out\n", name)
	}
	log.Logf(l4g.DEBUG, "RestGetPuzzle: received response for %v", name)
	if status == 200 {
		// send result on puzzleChan
		log.Logf(l4g.DEBUG, "RestGetPuzzle: sending puzzle on puzzleChan for %v", name)
		puzzleChan<-req.Result.(*Puzzle)
	} else {
		log.Logf(l4g.ERROR, "RestGetPuzzle: got status %v\n", status)
		// TODO: do something... retry?
		l4g.Crashf("RestGetPuzzle: could not get puzzle [%v] - bailing out\n", name)
	}
}

func RestGetSolver(name string) {
	log.Logf(l4g.DEBUG, "RestGetSolver: requesting token to fetch %v", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetSolver: releasing token from fetching %v", name)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()

	log.Logf(l4g.DEBUG, "RestGetSolver: preparing request for %v", name)
	client := restclient.New()
	req := restclient.RestRequest{
		Url:    pbRestUri+"/solvers/"+name,
		Method: restclient.GET,
		Result: new(Solver),
	}
	log.Logf(l4g.DEBUG, "RestGetSolver: sending request for %v", name)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "RestGetSolver: error %v\n", err)
		// TODO: do something... retry?
		l4g.Crashf("RestGetSolver: could not get solver [%v] - bailing out\n", name)
	}
	log.Logf(l4g.DEBUG, "RestGetSolver: received response for %v", name)
	if status == 200 {
		// send result on solverChan
		log.Logf(l4g.DEBUG, "RestGetSolver: sending solver on solverChan for %v", name)
		solverChan<-req.Result.(*Solver)
	} else {
		log.Logf(l4g.ERROR, "RestGetSolver: got status %v\n", status)
		// TODO: do something... retry?
		l4g.Crashf("RestGetSolver: could not get solver [%v] - bailing out\n", name)
	}
}

