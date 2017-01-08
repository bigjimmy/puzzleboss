package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"time"
	"strconv"
	"runtime"
)


var puzzleRevisionSeenP map[int64] bool

func init() {
	puzzleRevisionSeenP = make(map[int64] bool, 500) 
}

func BigJimmySolverActivityMonitor(solverName string, solverActivityMonitorChan chan *Solver) {
	log.Logf(l4g.INFO, "BigJimmySolverActivityMonitor(%v)\n", solverName)
	var solver *Solver
	go func() {
		for true {
			// set timer
			updateTimer := time.NewTimer(10 * time.Minute)
			
			// wait for timer or solver update
			log.Logf(l4g.TRACE, "BigJimmySolverActivityMonitor(%v): waiting for timer or solver update", solverName)
			
			select {
			   case <-updateTimer.C:
			     log.Logf(l4g.TRACE, "BigJimmySolverActivityMonitor(%v): timer went off!", solverName)
			     // if we have a solver, do the activity update
			     if solver != nil {
  			       updateSolverActivity(solverName, solver)
			     } else {
			       log.Logf(l4g.WARNING, "BigJimmySolverActivityMonitor(%v) timer went off before receiving solver\n", solverName)
			     }
			   case solver = <-solverActivityMonitorChan:
			     log.Logf(l4g.TRACE, "BigJimmySolverActivityMonitor(%v): have updated solver=%v", solverName, solver)
			     updateSolverActivity(solverName, solver)
			}
		}
	}()
}

func updateSolverActivity(solverName string, solver *Solver) {
	log.Logf(l4g.TRACE, "updateSolverActivity(%v, %v): %+v\n", solverName, solver.Name, solver)
	if solverName != solver.Name {
	  log.Logf(l4g.ERROR, "updateSolverActivity solver name mismatch: solverName=%v solver.Name=%v", solverName, solver.Name)
	  return
	}
	// TODO check solver activity in DB and take action through API if needed
	return
}


func BigJimmyDriveMonitor(puzzle *Puzzle) {
	log.Logf(l4g.INFO, "BigJimmyDriveMonitor(%v)\n", puzzle.Name)
	go func() {
		iteration := 0
		for true {
			iteration++;
			nGoRoutines := runtime.NumGoroutine()
			log.Logf(l4g.TRACE, "BigJimmyDriveMonitor: start of loop. currently in iteration %v for %v have %v goroutines.\n", iteration, puzzle.Name, nGoRoutines)
			// set timer
			updateTimer := time.NewTimer(30 * time.Second)
			
			// do the activity update
			updateDrivePuzzleActivity(puzzle)
			
			// wait for timer
			log.Logf(l4g.TRACE, "BigJimmyDriveMonitor: waiting for timer in iteration %v for %v.\n", iteration, puzzle.Name)
			<-updateTimer.C
			log.Logf(l4g.TRACE, "BigJimmyDriveMonitor: finished timer in iteration %v for %v.\n", iteration, puzzle.Name)
		}
	}()
}

func updateDrivePuzzleActivity(puzzle *Puzzle) (error) {
	log.Logf(l4g.TRACE, "updateDrivePuzzleActivity(%v)\n", puzzle.Name)
	
	// check puzzle revisions and comments
	if puzzle.Drive_id != "" {
		log.Logf(l4g.TRACE, "main(): before GetNewPuzzleRevisions, %v goroutines\n", runtime.NumGoroutine())
		revisions, err := GetNewPuzzleRevisions(puzzle.Drive_id)
		log.Logf(l4g.TRACE, "main(): after GetNewPuzzleRevisions, %v goroutines\n", runtime.NumGoroutine())
		if err != nil {
			log.Logf(l4g.ERROR, "updateDrivePuzzleActivity: error getting new puzzle revisions for puzzle [%v] id [%v]: %v\n", puzzle.Name, puzzle.Drive_id, err)
			return err
		}
		for _, revision := range revisions {
			var revisionId int64
			revisionId, err = strconv.ParseInt(revision.Id, 10, 64)
			if err != nil {
				log.Logf(l4g.ERROR, "updateDrivePuzzleActivity: could not parse revision.Id [%v] as int: %v\n", revision.Id, err)
			}
			
			if revision.LastModifyingUserName != "" {
				if !puzzleRevisionSeenP[revisionId] {
					puzzleRevisionSeenP[revisionId] = true
					log.Logf(l4g.TRACE, "main(): before ReportSolverPuzzleActivity, %v goroutines\n", runtime.NumGoroutine())
					ReportSolverPuzzleActivity(revision.LastModifyingUserName, puzzle.Name, revision.ModifiedDate, revisionId)
					log.Logf(l4g.TRACE, "main(): after ReportSolverPuzzleActivity, %v goroutines\n", runtime.NumGoroutine())
				}
			}
		}
	} else {
		// can't do anything without drive_id
		log.Logf(l4g.TRACE, "updateDrivePuzzleActivity: %v has no drive_id (yet?)\n", puzzle.Name)
	}
	return nil
}

