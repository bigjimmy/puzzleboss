package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"time"
)


func BigJimmySolverActivityMonitor(solver *Solver) {
	log.Logf(l4g.INFO, "BigJimmySolverActivityMonitor: starting for %v\n", solver.Name)
	go func() {
		// set timer
		updateTimer := time.NewTimer(10 * time.Minute)
		
		// do the activity update
		updateSolverActivity(solver)
		
		// wait for timer
		<-updateTimer.C
	}()
}

func updateSolverActivity(solver *Solver) {
	log.Logf(l4g.DEBUG, "updateSolverActivity: %v\n", solver.Name)
	
}


func BigJimmyDriveMonitor(puzzle *Puzzle) {
	log.Logf(l4g.INFO, "BigJimmyDriveMonitor: starting for %v\n", puzzle.Name)
	go func() {
		// set timer
		updateTimer := time.NewTimer(500 * time.Millisecond)
		
		// do the activity update
		updateDrivePuzzleActivity(puzzle)
		
		// wait for timer
		<-updateTimer.C
	}()
}


func updateDrivePuzzleActivity(puzzle *Puzzle) {
	log.Logf(l4g.DEBUG, "updateDrivePuzzleActivity: %v drive_id: %v\n", puzzle.Name, puzzle.Drive_id)
}

