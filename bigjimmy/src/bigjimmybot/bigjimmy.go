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

func BigJimmySolverActivityMonitor(solverFullName string, solverActivityMonitorChan chan *Solver) {
	log.Logf(l4g.INFO, "Creating BigJimmySolverActivityMonitor for solver %v", solverFullName)
	var solver *Solver
	go func() {
		for true {
			// set timer
			updateTimer := time.NewTimer(10 * time.Minute)
			
			// wait for timer or solver update
			log.Logf(l4g.TRACE, "BigJimmySolverActivityMonitor(%v): waiting for timer or solver update", solverFullName)
			
			select {
			   case <-updateTimer.C:
			     log.Logf(l4g.TRACE, "BigJimmySolverActivityMonitor(%v): timer went off!", solverFullName)
			     // if we have a solver, do the activity update
			     if solver != nil {
  			       updateSolverActivity(solverFullName, solver)
			     } else {
			       log.Logf(l4g.WARNING, "BigJimmySolverActivityMonitor(%v) timer went off before receiving solver", solverFullName)
			     }
			   case solver = <-solverActivityMonitorChan:
			     log.Logf(l4g.TRACE, "BigJimmySolverActivityMonitor(%v): have updated solver=%v", solverFullName, solver)
			     updateSolverActivity(solverFullName, solver)
			}
		}
	}()
}

func updateSolverActivity(solverFullName string, solver *Solver) {
	log.Logf(l4g.TRACE, "updateSolverActivity(%v): solver=%+v", solverFullName, solver)
	if solverFullName != solver.FullName {
	  log.Logf(l4g.ERROR, "updateSolverActivity solver name mismatch: solverFullName=%v solver.Name=%v", solverFullName, solver.FullName)
	  return
	}

	lastPuzzle, err := DbGetLastRevisedPuzzleForSolver(solver.Id)
	if err != nil {
	  log.Logf(l4g.ERROR, "updateSolverActivity: ERROR getting last revised puzzle for solver %v (%v)", solver.Id, solver.Name)
	  return
	}

	if lastPuzzle == "" {
	  log.Logf(l4g.TRACE, "updateSolverActivity: no revision activity for solver %v", solver.Name)
	  return
	}


	switch {
	case solver.Puzz == lastPuzzle: 
	  log.Logf(l4g.DEBUG, "updateSolverActivity: the last revision activity by %v was on puzzle %v, which is the puzzle solver is currently working on.", solver.Name, lastPuzzle)
	case solver.Puzz == "":
	  log.Logf(l4g.INFO, "updateSolverActivity: the last revision activity by %v was on puzzle %v, but solver is not currently working on any puzzle.", solver.Name, lastPuzzle)
	case solver.Puzz != lastPuzzle: 
	  log.Logf(l4g.INFO, "updateSolverActivity: the last revision activity by %v was on puzzle %v, but solver is currently working on puzzle %v.", solver.Name, lastPuzzle, solver.Puzz)
	}

	return
}


func BigJimmyDrivePuzzleMonitor(puzzleName string, puzzleActivityMonitorChan chan *Puzzle) {
	log.Logf(l4g.INFO, "BigJimmyDrivePuzzleMonitor(%v)", puzzleName)
	var puzzle *Puzzle
	go func() {
		iteration := 0
		for true {
			iteration++;
			nGoRoutines := runtime.NumGoroutine()
			log.Logf(l4g.TRACE, "BigJimmyDrivePuzzleMonitor: start of loop. currently in iteration %v for %v have %v goroutines.", iteration, puzzleName, nGoRoutines)

			// set timer
			updateTimer := time.NewTimer(30 * time.Second)
			
			// wait for timer or solver update
			log.Logf(l4g.TRACE, "BigJimmyDrivePuzzleMonitor(%v): waiting for timer or puzzle update", puzzleName)
			select {
			   case <-updateTimer.C:
			     log.Logf(l4g.TRACE, "BigJimmyDrivePuzzleMonitor(%v): timer went off!", puzzleName)
			     // if we have a puzzle, do the activity update
			     if puzzle != nil {
  			       updateDrivePuzzleActivity(puzzleName, puzzle)
			     } else {
			       log.Logf(l4g.WARNING, "BigJimmyDrivePuzzleMonitor(%v) timer went off before receiving solver", puzzleName)
			     }
			   case puzzle = <-puzzleActivityMonitorChan:
			     log.Logf(l4g.TRACE, "BigJimmyDrivePuzzleMonitor(%v): have updated puzzle=%v", puzzleName, puzzle)
			     updateDrivePuzzleActivity(puzzleName, puzzle)
			}
		}
	}()
}

func updateDrivePuzzleActivity(puzzleName string, puzzle *Puzzle) (err error) {
	log.Logf(l4g.TRACE, "updateDrivePuzzleActivity(%v): puzzle=%+v", puzzleName, puzzle)
	if puzzleName != puzzle.Name {
	  log.Logf(l4g.ERROR, "updatePuzzleActivity puzzle name mismatch: puzzleName=%v puzzle.Name=%v", puzzleName, puzzleName)
	  return
	}

	var revisions []Revision
	
	// check puzzle revisions and comments
	if puzzle.Drive_id != "" {
		log.Logf(l4g.TRACE, "main(): before GetNewPuzzleRevisions, %v goroutines", runtime.NumGoroutine())
		revisions, err = GetNewPuzzleRevisions(puzzle.Drive_id)
		log.Logf(l4g.TRACE, "main(): after GetNewPuzzleRevisions, %v goroutines", runtime.NumGoroutine())
		if err != nil {
			log.Logf(l4g.ERROR, "updateDrivePuzzleActivity: error getting new puzzle revisions for puzzle [%v] id [%v]: %v", puzzle.Name, puzzle.Drive_id, err)
			return
		}
		for _, revision := range revisions {
			var revisionId int64
			revisionId, err = strconv.ParseInt(revision.Id, 10, 64)
			if err != nil {
				log.Logf(l4g.ERROR, "updateDrivePuzzleActivity: could not parse revision.Id [%v] as int: %v", revision.Id, err)
			}
			
			if revision.LastModifyingFullName != "" {
				if !puzzleRevisionSeenP[revisionId] {
					puzzleRevisionSeenP[revisionId] = true
					log.Logf(l4g.TRACE, "main(): before ReportSolverPuzzleActivity, %v goroutines", runtime.NumGoroutine())
					ReportSolverPuzzleActivity(revision.LastModifyingFullName, puzzle.Name, revision.ModifiedDate, revisionId)
					log.Logf(l4g.TRACE, "main(): after ReportSolverPuzzleActivity, %v goroutines", runtime.NumGoroutine())
				}
			}
		}
	} else {
		// can't do anything without drive_id
		log.Logf(l4g.TRACE, "updateDrivePuzzleActivity: %v has no drive_id (yet?)", puzzle.Name)
	}
	return
}

func ReportSolverPuzzleActivity(solverFullName string, puzzleName string, modifiedDate string, revisionId int64) {
  log.Logf(l4g.TRACE, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v)", solverFullName, puzzleName, modifiedDate, revisionId)
  DbReportSolverPuzzleActivity(solverFullName, puzzleName, modifiedDate, revisionId)

  // notify activity monitor to update for this solver
  select {
    case solverActivityMonitorChans[solverFullName] <- solvers[solverFullName]:
      log.Logf(l4g.TRACE, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v): sending solvers[solverFullName]=%+v on channel", solverFullName, puzzleName, modifiedDate, revisionId, solvers[solverFullName])  
    default:
      log.Logf(l4g.WARNING, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v): failed to send solvers[solverFullName]=%+v on channel", solverFullName, puzzleName, modifiedDate, revisionId, solvers[solverFullName])  
  }
}

