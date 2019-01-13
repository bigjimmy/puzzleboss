package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"fmt"
	"time"
	"strconv"
	"runtime"
	"sync"
)

var puzzleRevisionSeenP map[string] bool
var puzzleRevisionSeenP_lock sync.RWMutex

func init() {
     puzzleRevisionSeenP = make(map[string] bool, 10000) 
}

func BigJimmySolverActivityMonitor(solver *Solver, solverActivityMonitorChan chan *Solver) {
	log.Logf(l4g.INFO, "Creating BigJimmySolverActivityMonitor for solver=%+v", solver)
	go func() {
		for true {
			// set timer
			updateTimer := time.NewTimer(3 * time.Minute)
			
			// wait for timer or solver update
			log.Logf(l4g.DEBUG, "BigJimmySolverActivityMonitor(%v): waiting for timer or solver update", solver.FullName)
			
			select {
			   case <-updateTimer.C:
			     log.Logf(l4g.DEBUG, "BigJimmySolverActivityMonitor(%v): timer went off!", solver.FullName)
			     // get a fresh solver whenever the timer goes off just in case it might be out of date
			     newSolver := RestGetSolverSync(solver.Name)
			     if newSolver.FullName != solver.FullName {
			        log.Logf(l4g.ERROR, "BigJimmySolverActivityMonitor(%v) new solver does not match! newSolver=%+v", solver.FullName, newSolver)
			        // todo handle this error (need to update channel map)
			     }
			     solver = newSolver
			     // commit updated solver to global solvers map
  			     log.Logf(l4g.DEBUG, "BigJimmySolverActivityMonitor(%v): attemping to lock solvers for writing", solver.FullName)
			     solvers_lock.Lock()
  			     log.Logf(l4g.DEBUG, "BigJimmySolverActivityMonitor(%v): have solvers write lock", solver.FullName)
			     solvers[solver.FullName] = solver
			     solvers_lock.Unlock()
  			     log.Logf(l4g.DEBUG, "BigJimmySolverActivityMonitor(%v): solvers write lock released", solver.FullName)

			     //updateSolverActivity(solver)
			   case solver = <-solverActivityMonitorChan:
			     log.Logf(l4g.DEBUG, "BigJimmySolverActivityMonitor(%v): have updated solver=%+v", solver.FullName, solver)
			     //updateSolverActivity(solver)
			}
		}
	}()
}

func updateSolverActivity(solver *Solver) {
	log.Logf(l4g.TRACE, "updateSolverActivity(solver=%+v)", solver)

	lastRevisedPuzzle, lastRevisionTime, err := DbGetLastRevisedPuzzleForSolver(solver.Id)
	if err != nil {
	  log.Logf(l4g.ERROR, "updateSolverActivity: ERROR getting last revised puzzle for solver %v (%v): %v", solver.Id, solver.Name, err)
	  return
	}

	// if there is no revision activity, no reason to proceed
	if lastRevisionTime.IsZero() {
	  log.Logf(l4g.TRACE, "updateSolverActivity: no revision activity for solver %v", solver.Name)
	  return
	}

	if solver.Puzz == lastRevisedPuzzle {
	  // get current puzzle for solver so we can check if it has been solved
  	  log.Logf(l4g.DEBUG, "updateSolverActivity(%v): attempting to lock puzzles for reading", solver.Name)
 	  puzzles_lock.RLock()
  	  log.Logf(l4g.DEBUG, "updateSolverActivity(%v): have puzzles read lock", solver.Name)
  	  puzzle, ok := puzzles[solver.Puzz]
  	  puzzles_lock.RUnlock()
  	  log.Logf(l4g.DEBUG, "updateSolverActivity(%v): puzzles read lock released", solver.Name)

	  if ok {
	    log.Logf(l4g.TRACE, "updateSolverActivity: solver %v is working on %v which is %v", solver.Name, puzzle.Name, puzzle.Status)
	    if puzzle.Status == "Solved" {
	      log.Logf(l4g.TRACE, "updateSolverActivity(%v): getting solve time for puzzle %v (%v)", solver.Name, puzzle.Id, puzzle.Name)
	      solveTime, err := DbGetSolveTimeForPuzzle(puzzle.Id)
	      if err != nil {
  	        log.Logf(l4g.WARNING, "updateSolverActivity(%v): could not get solve time for puzzle %v (%v): %v", solver.Name, puzzle.Id, puzzle.Name, err)
	      }
	      log.Logf(l4g.TRACE, "updateSolverActivity(%v): solve time for puzzle %v (%v) is %v (last revision by solver was at %v)", solver.Name, puzzle.Id, puzzle.Name, solveTime, lastRevisionTime)
	      if lastRevisionTime.After(solveTime) {
	        if lastRevisionTime.Sub(solveTime) > 5 * time.Minute {
	          log.Logf(l4g.INFO, "updateSolverActivity: solver %v continued to work on puzzle %v for %v since it was solved", solver.Name, puzzle.Name, lastRevisionTime.Sub(solveTime))
		  //SendSlackSolverMessage(solver, fmt.Sprintf("You seem to still be editing a spreadsheet for a solved puzzle (%v)", puzzle.Name))
	        }
	      }
	      timeSinceSolve := time.Since(solveTime)
	      if timeSinceSolve > 15 * time.Minute {
	        log.Logf(l4g.INFO, "updateSolverActivity: solver %v is still assigned to a solved puzzle (%v) after %v", solver.Name, solver.Puzz, timeSinceSolve)
		  //SendSlackSolverMessage(solver, fmt.Sprintf("You are still assigned to a solved puzzle (%v), please update your status at: https://wind-up-birds.org/puzzleboss/bin/overview.pl", puzzle.Name))
	      }	 
	    }
     	  } else {
	    log.Logf(l4g.WARNING, "updateSolverActivity(%v): no information on puzzle %v yet", solver.Name, solver.Puzz)
	  }
	  
	  if time.Since(lastRevisionTime) > 3 * time.Hour {
	    log.Logf(l4g.INFO, "updateSolverActivity: solver %v is supposedly working on %v but has not edited sheets in %v (since %v)", solver.Name, solver.Puzz, time.Since(lastRevisionTime), lastRevisionTime)
	    //SendSlackSolverMessage(solver, fmt.Sprintf("Are you still working on %v or are you taking a break? Please update your status at: https://wind-up-birds.org/puzzleboss/bin/overview.pl", solver.Puzz))

	    // if it has been a very very long time since last revision, just set solver to taking a break
	    if time.Since(lastRevisionTime) > 12 * time.Hour {
	      // 12 hours is just took long to work on a puzzle without editing it, set this solver to taking a break (among other things, this should fix pre-hunt assignments)
	      log.Logf(l4g.INFO, "BIGJIMMY DECREES: solver %v is taking a break! (has been working on %v with no edits for %v)", solver.Name, solver.Puzz, time.Since(lastRevisionTime))
	      log.Logf(l4g.DEBUG, "updateSolverActivity: calling PbRestPost to set solver %v to taking a break", solver.Name)
	      PbRestPost("solvers/"+solver.Name+"/puzz", PartPost{Data: ""})
	      log.Logf(l4g.DEBUG, "updateSolverActivity: back from PbRestPost setting solver %v to taking a break", solver.Name)
	    }
	    return
	  }
	  log.Logf(l4g.DEBUG, "updateSolverActivity: the last revision activity by %v was on puzzle %v, which is the puzzle solver is currently working on.", solver.Name, lastRevisedPuzzle)
	  return
	}

	// if it has been more than 6 hours since the revision, its too late to be useful
	if time.Since(lastRevisionTime) > 6 * time.Hour {
	  log.Logf(l4g.TRACE, "updateSolverActivity: solver %v has not revised anything in more than six hours, no point checking for interactions (last revision time %v)", solver.FullName, lastRevisionTime)
	  return
	}

	// get last interaction
	lastInteractedPuzzle, lastInteractionTime, err := DbGetLastInteractionPuzzleForSolver(solver.Id)
	if err != nil {
	  log.Logf(l4g.ERROR, "updateSolverActivity: ERROR getting last interacted puzzle for solver %v (%v): %v", solver.Id, solver.Name, err)
   	  return
	}
	lastInteractedDesc := "on puzzle "+lastInteractedPuzzle
	if lastInteractedPuzzle == "" {
	  lastInteractedDesc = "taking a break"
	}

	log.Logf(l4g.DEBUG, "updateSolverActivity: have lastRevisedPuzzle=[%v] lastRevisionTime=[%v] lastInteractedPuzzle=[%v] lastInteractionTime=[%v] lastInteractedDesc=[%v] for solver=[%+v]", lastRevisedPuzzle, lastRevisionTime, lastInteractedPuzzle, lastInteractionTime, lastInteractedDesc, solver)

	// if interaction is more recent than revision, we aren't interested, yo.
	if !lastRevisionTime.After(lastInteractionTime) {
	  log.Logf(l4g.DEBUG, "updateSolverActivity: interaction more recent than puzzle revision for solver %v, taking no action", solver.Name)
	  return
	}

	solverChangeMessage := ""
  	switch {
	case solver.Puzz == "":
	    if lastInteractionTime.IsZero() {
	      solverChangeMessage = "has joined the hunt and is now working on %v"
	      //SendSlackSolverMessage(solver, fmt.Sprintf("Welcome to the hunt! I see you are now working on %v. If you decide to take a break, please let us know by changing your status at https://wind-up-birds.org/puzzleboss/bin/overview.pl", lastRevisedPuzzle))
	    } else {
	      solverChangeMessage = "is done taking a break and is now working on"
	      //SendSlackSolverMessage(solver, "Welcome back from your break!")
	    }
	case solver.Puzz != lastRevisedPuzzle: 
	    // revision was to a puzzle other than the one the solver is supposedly currently working on
	    if lastRevisionTime.Sub(lastInteractionTime) > 5 * time.Minute {
	      solverChangeMessage = fmt.Sprintf("was working on %v but is now working on", solver.Puzz)
	    } else {
	      // interaction was within 5 minutes of revision, do not override
	      log.Logf(l4g.DEBUG, "updateSolverActivity: solver %v had explicit puzzle interaction (%v) just prior to revision (to %v at %v), not making any changes", solver.Name, lastInteractedDesc, lastRevisedPuzzle, lastRevisionTime)
	      return
	    }
	}

	// get the status of the revised puzzle so we can check if it has been solved
  	log.Logf(l4g.DEBUG, "updateSolverActivity(%v): attempting to lock puzzles for reading", solver.Name)
 	puzzles_lock.RLock()
  	log.Logf(l4g.DEBUG, "updateSolverActivity(%v): have puzzles read lock", solver.Name)
  	puzzle, ok := puzzles[lastRevisedPuzzle]
  	puzzles_lock.RUnlock()
  	log.Logf(l4g.DEBUG, "updateSolverActivity(%v): puzzles read lock released", solver.Name)
	if ok {
	  if puzzle.Status == "Solved" {
	    // solver appears to be working on a solved puzzle, do not assign them to it
	    log.Logf(l4g.INFO, "updateSolverActivity: solver %v %v %v (BUT THIS PUZZLE IS SOLVED!) (revision as of %v, last interaction was %v at %v), not changing active puzzle.", solver.Name, solverChangeMessage, lastRevisedPuzzle, lastRevisionTime, lastInteractedDesc, lastInteractionTime)
	    //SendSlackSolverMessage(solver, fmt.Sprintf("The puzzle you are working on (%v) has been solved. Find a new puzzle at: https://wind-up-birds.org/puzzleboss/bin/overview.pl", puzzle.Name))
	    return	  
	  }
	} else {
 	    puzzles_lock.RLock()
	    log.Logf(l4g.ERROR, "updateSolverActivity(%v): serious inconsistency - solver has revised a puzzle (%v) we don't know about. we know about puzzles: %+v", solver.Name, lastRevisedPuzzle, puzzles)
  	    puzzles_lock.RUnlock()
	}

	log.Logf(l4g.INFO, "BIGJIMMY DECREES: solver %v %v %v! (revision as of %v, last interaction was %v at %v), and so it shall be.", solver.Name, solverChangeMessage, lastRevisedPuzzle, lastRevisionTime, lastInteractedDesc, lastInteractionTime)
	//SendSlackSolverMessage(solver, fmt.Sprintf("I notice you are working on the spreadsheet for %v, so I'm assigning you to it!", lastRevisedPuzzle))
	log.Logf(l4g.DEBUG, "updateSolverActivity: calling PbRestPost to set solver %v to %v", solver.Name, lastRevisedPuzzle)
	PbRestPost("solvers/"+solver.Name+"/puzz", PartPost{Data: lastRevisedPuzzle})
	log.Logf(l4g.DEBUG, "updateSolverActivity: back from PbRestPost setting solver %v to %v", solver.Name, lastRevisedPuzzle)
	return
}


func (d *Drive) BigJimmyDrivePuzzleMonitor(puzzleName string, puzzleActivityMonitorChan chan *Puzzle) {
	log.Logf(l4g.INFO, "BigJimmyDrivePuzzleMonitor(%v)", puzzleName)
	var puzzle *Puzzle
	go func() {
		iteration := 0
		for true {
			iteration++;
			nGoRoutines := runtime.NumGoroutine()
			log.Logf(l4g.DEBUG, "BigJimmyDrivePuzzleMonitor: start of loop. currently in iteration %v for %v have %v goroutines.", iteration, puzzleName, nGoRoutines)

			// set timer
			updateTimer := time.NewTimer(10 * time.Minute)
			
			// wait for timer or solver update
			log.Logf(l4g.DEBUG, "BigJimmyDrivePuzzleMonitor(%v): waiting for timer or puzzle update", puzzleName)
			select {
			   case <-updateTimer.C:
			     log.Logf(l4g.DEBUG, "BigJimmyDrivePuzzleMonitor(%v): timer went off!", puzzleName)
			     // if we have a puzzle, do the activity update
			     if puzzle != nil {
  			       d.updateDrivePuzzleActivity(puzzleName, puzzle)
			     } else {
			       log.Logf(l4g.WARNING, "BigJimmyDrivePuzzleMonitor(%v) timer went off before receiving solver", puzzleName)
			     }
			   case puzzle = <-puzzleActivityMonitorChan:
			     log.Logf(l4g.TRACE, "BigJimmyDrivePuzzleMonitor(%v): have updated puzzle=%v", puzzleName, puzzle)
			     d.updateDrivePuzzleActivity(puzzleName, puzzle)
			}
		}
	}()
}

func (d *Drive) updateDrivePuzzleActivity(puzzleName string, puzzle *Puzzle) (err error) {
	log.Logf(l4g.TRACE, "updateDrivePuzzleActivity(%v): puzzle=%+v", puzzleName, puzzle)
	if puzzleName != puzzle.Name {
	  log.Logf(l4g.ERROR, "updatePuzzleActivity puzzle name mismatch: puzzleName=%v puzzle.Name=%v", puzzleName, puzzleName)
	  return
	}

	// check latest puzzle revision
	// todo could also check comments?
	var revision Revision
	if puzzle.Drive_id == "" {
		// can't do anything without drive_id
		err = fmt.Errorf("updateDrivePuzzleActivity: %v has no drive_id (yet?)", puzzle.Name)
		return
	}
	revision, err = d.GetLatestPuzzleRevision(puzzle.Drive_id)	
	if err != nil {
		log.Logf(l4g.ERROR, "updateDrivePuzzleActivity: failed to get latest revision for puzzle %v", puzzleName)
		return
	}

	if revision.LastModifyingFullName == "" {
		log.Logf(l4g.WARNING, "updateDrivePuzzleActivity: ignoring revision by unknown last modifying user: %v", revision)
		return		
	}

	var revisionId int64
	revisionId, err = strconv.ParseInt(revision.Id, 10, 64)
	if err != nil {
		log.Logf(l4g.ERROR, "updateDrivePuzzleActivity: could not parse revision.Id [%v] as int: %v", revision.Id, err)
		return
	}

	seenKey := fmt.Sprintf("%s_%s_%s", puzzle.Drive_id, revision.LastModifyingFullName, revision.ModifiedDate)
	puzzleRevisionSeenP_lock.RLock()
	_, ok := puzzleRevisionSeenP[seenKey]
	puzzleRevisionSeenP_lock.RUnlock()
	if !ok {
		puzzleRevisionSeenP_lock.Lock()
		puzzleRevisionSeenP[seenKey] = true
		puzzleRevisionSeenP_lock.Unlock()
		if revision.LastModifyingFullName == "Big Jimmy" {
			log.Logf(l4g.INFO, "updateDrivePuzzleActivity: ignoring revision by Big Jimmy: %v", revision)
			return
		}

		log.Logf(l4g.DEBUG, "main(): before ReportSolverPuzzleActivity, %v goroutines", runtime.NumGoroutine())
		ReportSolverPuzzleActivity(revision.LastModifyingFullName, puzzle.Name, revision.ModifiedDate, revisionId)
		log.Logf(l4g.DEBUG, "main(): after ReportSolverPuzzleActivity, %v goroutines", runtime.NumGoroutine())
	}		
	return
}

func ReportSolverPuzzleActivity(solverFullName string, puzzleName string, modifiedDate string, revisionId int64) {
  log.Logf(l4g.TRACE, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v)", solverFullName, puzzleName, modifiedDate, revisionId)
  DbReportSolverPuzzleActivity(solverFullName, puzzleName, modifiedDate, revisionId, "revise")
  
  
  log.Logf(l4g.DEBUG, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v): attemping to lock solvers for reading", solverFullName, puzzleName, modifiedDate, revisionId)
  solvers_lock.RLock()
  log.Logf(l4g.DEBUG, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v): have solvers read lock", solverFullName, puzzleName, modifiedDate, revisionId)
  solver := solvers[solverFullName]
  solvers_lock.RUnlock()
  log.Logf(l4g.DEBUG, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v): solvers read lock released", solverFullName, puzzleName, modifiedDate, revisionId)

  // notify activity monitor to update for this solver
  select {
    case solverActivityMonitorChans[solverFullName] <- solver:
      log.Logf(l4g.DEBUG, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v): sending solver=%+v on channel", solverFullName, puzzleName, modifiedDate, revisionId, solver)  
    default:
      log.Logf(l4g.WARNING, "ReportSolverPuzzleActivity(solverFullName=%v, puzzleName=%v, modifiedDate=%v, revisionId=%v): failed to send solver=%+v on channel", solverFullName, puzzleName, modifiedDate, revisionId, solver)  
  }
}

