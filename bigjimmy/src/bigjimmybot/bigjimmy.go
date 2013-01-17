package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"time"
)


func BigJimmyDriveMonitor(puzzle *Puzzle) {
	log.Logf(l4g.INFO, "BigJimmyDriveMonitor: starting for %v\n", puzzle.Name)
	go func() {
		// set timer
		monitorTimer := time.NewTimer(500 * time.Millisecond)
		
		// do the activity update
		monitorDrivePuzzleActivity(puzzle)
		
		// wait for timer
		<-monitorTimer.C
	}()
}


func monitorDrivePuzzleActivity(puzzle *Puzzle) {
	log.Logf(l4g.DEBUG, "monitorDrivePuzzle: %v drive_id: %v\n", puzzle.Name, puzzle.Drive_id)
}