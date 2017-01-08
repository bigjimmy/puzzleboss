package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
)

type Solver struct {
	Id string
	Name string
	Puzz string
}

var solvers map[string] *Solver
var solverChan chan *Solver

var restGetSolversDone chan int

var solversArrived int = 0

func init() {
	solverChan = make(chan *Solver, 10)
	restGetSolversDone = make(chan int) // must not be buffered!
	solvers = make(map[string] *Solver, 500) 
        solverActivityMonitorChans := make(map[string] chan *Solver, 500)

	// get solvers from solverChan, shovel them into solvers map, and dispatch to solver activity monitor
	go func(){
		for true {
			log.Logf(l4g.TRACE, "solverChan listener: waiting for new solver\n")
			solver := <-solverChan // this will block waiting for new solvers
			log.Logf(l4g.TRACE, "solverChan listener: got new solver %+v\n", solver)
			
			if _, ok := solverActivityMonitorChans[solver.Name]; !ok {
			   log.Logf(l4g.TRACE, "solverChan listener: no activity monitor yet for solver.Name: %v\n", solver.Name)
			   // setup a channel to pass solver updates to solver activity monitor
			   solverActivityMonitorChans[solver.Name] = make(chan *Solver, 10)
			   // start a bigjimmy google drive monitor for this solver
			   BigJimmySolverActivityMonitor(solver.Name, solverActivityMonitorChans[solver.Name])
			}

			// pass updated solver to existing or just created BigJimmySolverActivityMonitor
			log.Logf(l4g.TRACE, "solverChan listener: sending solver on activity monitor chan: %+v\n", solver)
			solverActivityMonitorChans[solver.Name] <- solver
			log.Logf(l4g.TRACE, "solverChan listener: solver sent: %+v\n", solver)

			solvers[solver.Name] = solver
			solversArrived++
			log.Logf(l4g.DEBUG, "solverChan listener: %v >= %v ?", solversArrived, SolverCount)
			if solversArrived >= SolverCount {
				restGetSolversDone<-1
			}
		}
	}()
}


