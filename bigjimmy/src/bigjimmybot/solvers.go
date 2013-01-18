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

	// get solvers from solverChan and shovel them into solvers map
	go func(){
		for true {
			log.Logf(l4g.TRACE, "solverChan listener: waiting for new solver\n")
			solver := <-solverChan // this will block waiting for new solvers
			log.Logf(l4g.INFO, "solverChan listener: got new solver %+v\n", solver)

			solvers[solver.Name] = solver
			solversArrived++
			log.Logf(l4g.DEBUG, "solverChan listener: %v >= %v ?", solversArrived, SolverCount)
			if solversArrived >= SolverCount {
				restGetSolversDone<-1
			}
			
			// start a bigjimmy google drive monitor for this solver
			BigJimmySolverActivityMonitor(solver)
		}
	}()
}


