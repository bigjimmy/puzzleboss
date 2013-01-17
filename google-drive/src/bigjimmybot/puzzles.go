package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"github.com/jmcvetta/restclient"
)

type Puzzle struct {
	Id string
	Name string
	Round string
	Status string
	Answer string
	Xyzloc string
	Locations string
	Solvers string
	Cursolvers string
	Comments string
	Gssuri string
	Uri string
	Wrong_answers string
	Drive_id string
}

var puzzles map[string] *Puzzle
var puzzleChan chan *Puzzle

var restGetPuzzlesDone chan int

var puzzlesArrived int = 0

func init() {
	puzzleChan = make(chan *Puzzle, 10)
	restGetPuzzlesDone = make(chan int) // must not be buffered!
	puzzles = make(map[string] *Puzzle, 500) 

	// get puzzles from puzzleChan
	go func(){
		for true {
			puzzle := <-puzzleChan // this will block waiting for new puzzles
			puzzles[puzzle.Name] = puzzle
			puzzlesArrived++
			log.Logf(l4g.DEBUG, "puzzleChan listener: %v >= %v ?", puzzlesArrived, PuzzleCount)
			if puzzlesArrived >= PuzzleCount {
				restGetPuzzlesDone<-1
			}
			
			// check if we have a google drive id
			if puzzle.Drive_id == "" {
				// don't have Drive_id 
				// TODO: could look it up by name and ensure that it is in the root hunt folder
				log.Logf(l4g.ERROR, "puzzleChan listener: don't have drive ID for puzzle %v\n", puzzle.Name)
				continue // skip handlking this pzuzle for now
			}
			
			// start a bigjimmy google drive monitor for this puzzle
			BigJimmyDriveMonitor(puzzle)
		}
	}()
}


func RestGetPuzzle(name string) {
	log.Logf(l4g.DEBUG, "RestGetPuzzle: requesting token to fetch %v", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetPuzzle: releasing token from fetching %v", name)
		<-httpRestReqLimiter // take a token out of the limiting channel
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
		log.Logf(l4g.ERROR, "restGetPuzzle: error %v\n", err)
		// TODO: do something... retry?
	}
	log.Logf(l4g.DEBUG, "RestGetPuzzle: received response for %v", name)
	if status == 200 {
		// send result on puzzleChan
		log.Logf(l4g.DEBUG, "RestGetPuzzle: sending puzzle on puzzleChan for %v", name)
		puzzleChan<-req.Result.(*Puzzle)
	} else {
		log.Logf(l4g.ERROR, "RestGetPuzzle: got status %v\n", status)
		// TODO: do something... retry?
	}
}

