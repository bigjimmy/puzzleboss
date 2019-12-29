package bigjimmybot

import (
        "sync"
	l4g "code.google.com/p/log4go"
	"time"
)

type Round struct {
	Id int
	Name string
	Round_uri string
	Drive_uri string
	Drive_id string
}

var rounds map[string] *Round
var rounds_lock sync.RWMutex
var roundChan chan *Round

var restGetRoundsDone chan int

var roundsArrived int = 0

func (d *Drive) MonitorRounds() {
	roundChan = make(chan *Round, 10)
	restGetRoundsDone = make(chan int) // must not be buffered!
	rounds = make(map[string] *Round, 500) 

	// get rounds from roundChan and shovel them into rounds map
	go func(){
		for true {
			log.Logf(l4g.TRACE, "roundChan listener: waiting for new round")
			round := <-roundChan // this will block waiting for new rounds
			log.Logf(l4g.INFO, "roundChan listener: got new round %+v", round)
			
			if round.Drive_id == "" {
				// don't have a drive_id for this round
				// create round folder in Google Drive 
				roundFolderId, roundFolderUri, err := d.CreateRound(round.Name, huntFolderId)
				if err != nil {
					log.Logf(l4g.ERROR, "roundChan listener: could not create round [%v] in huntFolderId=[%v]: %v", round.Name, huntFolderId, err)
					// retry 3 times
					retry := 3
					for err != nil && retry > 0 {
						// set timer
						roundWaitTimer := time.NewTimer(500 * time.Millisecond)
						// block on timer channel
						<-roundWaitTimer.C
						log.Logf(l4g.ERROR, "roundChan listener: retrying CreateRound(%v, %v)", round.Name, huntFolderId)
						roundFolderId, roundFolderUri, err = d.CreateRound(round.Name, huntFolderId)
						
					}
					if err != nil {
						l4g.Crashf("roundChan listener: retried CreateRound(%v, %v) 3 times and all failed -- bailing out!", round.Name, huntFolderId)
					}
				} 
				// creation should have succeeded
				
				// update local and remote drive_id and drive_uri
				round.Drive_id = roundFolderId
				go PbRestPost("rounds/"+round.Name+"/drive_id", PartPost{Data: roundFolderId})
				round.Drive_uri = roundFolderUri
				go PbRestPost("rounds/"+round.Name+"/drive_uri", PartPost{Data: roundFolderUri})
			} 

  			log.Logf(l4g.DEBUG, "roundChan listener: attemping to lock rounds for writing")
			rounds_lock.Lock()
  			log.Logf(l4g.DEBUG, "roundChan listener: have rounds write lock")
			rounds[round.Name] = round
			rounds_lock.Unlock()
  			log.Logf(l4g.DEBUG, "roundChan listener: rounds write lock released")

			roundsArrived++
			
			log.Logf(l4g.DEBUG, "roundChan listener: %v >= %v ?", roundsArrived, RoundCount)
			if roundsArrived >= RoundCount {
				restGetRoundsDone<-1
			}
			
			// start a bigjimmy google drive monitor for this round (if we needed round folder monitoring)
			// BigJimmyRoundActivityMonitor(round)
		}
	}()
}

