package bigjimmybot

import (
	"fmt"
	"database/sql"
	"time"
	_ "github.com/go-sql-driver/mysql"
	l4g "code.google.com/p/log4go"
)

var dbCon *sql.DB


// Open/Close DB
func OpenDB(dbUser string, dbPassword string, dbProtocol string, dbHost string, dbPort string, dbName string) {
	// Connect to database
	mysqlDsn := dbUser+":"+dbPassword+"@"+dbProtocol+"("+dbHost+":"+dbPort+")/"+dbName+"?parseTime=true"
	var err error
	dbCon, err = sql.Open("mysql", mysqlDsn)
	if err != nil {
		l4g.Crashf("could not connect to mysql database with DSN %v: %v", mysqlDsn, err)
	}
}
func CloseDB() {
	dbCon.Close()
}


// Get/Set Config
func DbGetConfig(key string) (val string, err error) {
	var valNS sql.NullString
	row := dbCon.QueryRow("SELECT `val` FROM `config` WHERE `key` = '"+key+"'")
	//defer row.Close()
	err = row.Scan(&valNS)
	if err != nil {
		log.Logf(l4g.INFO, "dbGetConfig: SELECT unsuccessful for [key=%v]: %v", key, err)
		return
	}
	if valNS.Valid {
		val = valNS.String
	} else {
		// null string
		err = fmt.Errorf("dbGetConfig got NULL value for key %v", key)
	}
	return
}
func DbSetConfig(key string, val string) (err error) {
	_, err = dbCon.Exec("REPLACE INTO `config` (`key`, `val`) VALUES (?, ?)", key, val)
	if err != nil {
		log.Logf(l4g.ERROR, "dbSetConfig: INSERT unsuccessful: %v", err)
	}
	return
}

func DbGetLastActivityForSolver(solverId string, activityType string) (puzzle string, timestamp time.Time, err error) {
	var puzzleNS sql.NullString
	err = dbCon.QueryRow("SELECT `puzzle`.`name`, `activity`.`time` FROM `activity` LEFT JOIN `puzzle` ON `puzzle`.`id` = `activity`.`puzzle_id` WHERE `activity`.`solver_id` = ? AND `activity`.`type` = ? ORDER BY `activity`.`time` DESC LIMIT 1", solverId, activityType).Scan(&puzzleNS, &timestamp)
	switch {
	case err == sql.ErrNoRows:
	     puzzle = ""
	     // returned timestamp will be zero time, which is a very long time ago
	     err = nil
	     return
	case err != nil:
		log.Logf(l4g.ERROR, "DbGetLastActivityForSolver: SELECT unsuccessful for [solver_id=%v]: %v", solverId, err)
		return
	}
	if puzzleNS.Valid {
		puzzle = puzzleNS.String
	} else {
		// the null puzzle is ok
		log.Logf(l4g.DEBUG, "DbGetLastActivityForSolver: got NULL value for puzzle searching for last activity for solverId=%v", solverId)
		puzzle = ""
		return
	}
	return
}

func DbGetLastInteractionPuzzleForSolver(solverId string) (puzzle string, timestamp time.Time, err error) {
	puzzle, timestamp, err = DbGetLastActivityForSolver(solverId, "interact")
	return
}

// Query/Report Puzzle Revision Activity
func DbGetLastRevisedPuzzleForSolver(solverId string) (puzzle string, timestamp time.Time, err error) {
	puzzle, timestamp, err = DbGetLastActivityForSolver(solverId, "revise")
	return
}

func DbReportSolverPuzzleActivity(solverFullName string, puzzleName string, modifiedDate string, revisionId int64, activityType string) {
	_, err := dbCon.Exec("INSERT INTO `activity` (`time`, `solver_id`, `puzzle_id`, `source`, `type`, `source_version`) VALUES (?, (SELECT `id` FROM `solver` WHERE `solver`.`fullname` LIKE ?), (SELECT `id` FROM `puzzle` WHERE `puzzle`.`name` LIKE ?), 'google', ?, ?)", modifiedDate, solverFullName, puzzleName, activityType, revisionId)
	if err != nil {
		log.Logf(l4g.ERROR, "ReportSolverPuzzleActivity: INSERT unsuccessful for solverFullName=[%v] puzzleName=[%v] modifiedDate=[%v] revisionId=[%v] activityType=[%v]: %v", solverFullName, puzzleName, modifiedDate, revisionId, activityType, err)
	}
	return
}
