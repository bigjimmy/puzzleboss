package bigjimmybot

import (
	"sync"
	l4g "code.google.com/p/log4go"
)

type Solver struct {
	Id int
	Name string
	FullName string
	Puzz string
}

var solvers map[string] *Solver
var solvers_lock sync.RWMutex
var solverActivityMonitorChans map[string] chan *Solver

var solverChan chan *Solver

var restGetSolversDone chan int

var solversArrived int = 0

func MonitorSolvers() {
	solverChan = make(chan *Solver, 10)
	restGetSolversDone = make(chan int) // must not be buffered!
	solvers = make(map[string] *Solver, 500) 
        solverActivityMonitorChans = make(map[string] chan *Solver, 500)

	// get solvers from solverChan, shovel them into solvers map, and dispatch to solver activity monitor
	go func(){
		for true {
			log.Logf(l4g.TRACE, "solverChan listener: waiting for new/updated solver")
			solver := <-solverChan // this will block waiting for new/updated solvers
			log.Logf(l4g.TRACE, "solverChan listener: got new/updated solver %+v", solver)
			
			if _, ok := solverActivityMonitorChans[solver.FullName]; !ok {
			   log.Logf(l4g.TRACE, "solverChan listener: no activity monitor yet for solver.FullName: %v", solver.FullName)
			   // setup a channel to pass solver updates to solver activity monitor
			   solverActivityMonitorChans[solver.FullName] = make(chan *Solver, 10)
			   // start a bigjimmy google drive monitor for this solver
			   BigJimmySolverActivityMonitor(solver, solverActivityMonitorChans[solver.FullName])
			}

			// pass updated solver to existing or just created BigJimmySolverActivityMonitor
			log.Logf(l4g.TRACE, "solverChan listener: sending solver on activity monitor chan: %+v", solver)
			// TODO: only send the latest update for each solver in a batch
			solverActivityMonitorChans[solver.FullName] <- solver
			log.Logf(l4g.TRACE, "solverChan listener: solver sent: %+v", solver)

  			log.Logf(l4g.DEBUG, "solverChan listener: attemping to lock solvers for writing")
			solvers_lock.Lock()
  			log.Logf(l4g.DEBUG, "solverChan listener: have solvers write lock")
			solvers[solver.FullName] = solver
			solvers_lock.Unlock()
  			log.Logf(l4g.DEBUG, "solverChan listener: solvers write lock released")

			solversArrived++
			log.Logf(l4g.DEBUG, "solverChan listener: %v >= %v ?", solversArrived, SolverCount)
			if solversArrived >= SolverCount {
				restGetSolversDone<-1
			}
		}
	}()
}


