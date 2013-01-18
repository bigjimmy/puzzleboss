package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"github.com/jmcvetta/restclient"
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
			solver := <-solverChan // this will block waiting for new solvers
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


func RestGetSolver(name string) {
	log.Logf(l4g.DEBUG, "RestGetSolver: requesting token to fetch %v", name)
	httpRestReqLimiter<-1 // put a token in the limiting channel
	defer func() {
		log.Logf(l4g.DEBUG, "RestGetSolver: releasing token from fetching %v", name)
		<-httpRestReqLimiter // release a token from the limiting channel
	}()

	log.Logf(l4g.DEBUG, "RestGetSolver: preparing request for %v", name)
	client := restclient.New()
	req := restclient.RestRequest{
		Url:    pbRestUri+"/solvers/"+name,
		Method: restclient.GET,
		Result: new(Solver),
	}
	log.Logf(l4g.DEBUG, "RestGetSolver: sending request for %v", name)
	status, err := client.Do(&req)
	if err != nil {
		log.Logf(l4g.ERROR, "restGetSolver: error %v\n", err)
		// TODO: do something... retry?
	}
	log.Logf(l4g.DEBUG, "RestGetSolver: received response for %v", name)
	if status == 200 {
		// send result on solverChan
		log.Logf(l4g.DEBUG, "RestGetSolver: sending solver on solverChan for %v", name)
		solverChan<-req.Result.(*Solver)
	} else {
		log.Logf(l4g.ERROR, "RestGetSolver: got status %v\n", status)
		// TODO: do something... retry?
	}
}

