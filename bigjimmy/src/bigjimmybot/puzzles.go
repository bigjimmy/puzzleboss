package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"time"
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
	Uri string
	Drive_uri string
	Drive_id string
	Wrong_answers string
}

var puzzles map[string] *Puzzle
var puzzleChan chan *Puzzle

var restGetPuzzlesDone chan int

var puzzlesArrived int = 0

func init() {
	puzzleChan = make(chan *Puzzle, 10)
	restGetPuzzlesDone = make(chan int) // must not be buffered!
	puzzles = make(map[string] *Puzzle, 500) 

	// get puzzles from puzzleChan and shovel them into puzzles map
	go func(){
		for true {
			log.Logf(l4g.TRACE, "puzzleChan listener: waiting for new puzzle\n")
			puzzle := <-puzzleChan // this will block waiting for new puzzles
			log.Logf(l4g.INFO, "puzzleChan listener: got new puzzle %+v\n", puzzle)

			// check if we have a google drive id
			if puzzle.Drive_id == "" {
				// don't have Drive_id already
				
				// create spreadsheet in Google Drive 
				// TODO: could be asynchronous?
				round, ok := rounds[puzzle.Round]
				if !ok {
					// perhaps puzzle was added to a non-existant round, or round folder creation is still pending
					// TODO: what to do?  for now, just wait forever for it, blocking the puzzle creation loop
					log.Logf(l4g.ERROR, "puzzleChan listener: don't have round for round [%v], delaying creation of puzzle [%v]\n", puzzle.Round, puzzle.Name)
					for !ok {
						// set timer
						roundWaitTimer := time.NewTimer(1 * time.Second)
						// block on timer channel
						<-roundWaitTimer.C
						log.Logf(l4g.INFO, "puzzleChan listener: retrying search for round [%v] in rounds map\n", puzzle.Round)
						
						// retry the rounds map
						round, ok = rounds[puzzle.Round]
					}
					// now we should have a round with a Drive_id
				}
				roundFolderId := round.Drive_id
				ssId, ssUri, err := CreatePuzzle(puzzle.Name, roundFolderId)
				if err != nil {
					log.Logf(l4g.ERROR, "puzzleChan listener: could not create puzzle [%v] in roundFolderId [%v]: %v\n", puzzle.Name, roundFolderId, err)
				}
				log.Logf(l4g.INFO, "puzzleChan listener: created puzzle [%v] with ssId=[%v] ssUri[%v]\n", puzzle.Name, ssId, ssUri)
				
				// update local and remote drive_id and drive_uri
				puzzle.Drive_id = ssId
				go PbRestPost("puzzles/"+puzzle.Name+"/drive_id", PartPost{Data: ssId})
				puzzle.Drive_uri = ssUri
				go PbRestPost("puzzles/"+puzzle.Name+"/drive_uri", PartPost{Data: ssUri})
			}
			

			puzzles[puzzle.Name] = puzzle
			puzzlesArrived++
			log.Logf(l4g.DEBUG, "puzzleChan listener: %v >= %v ?", puzzlesArrived, PuzzleCount)
			if puzzlesArrived >= PuzzleCount {
				restGetPuzzlesDone<-1
			}
			
			// start a bigjimmy google drive monitor for this puzzle
			BigJimmyDriveMonitor(puzzle)
		}
	}()
}



