package bigjimmybot

import (
	"fmt"
	"database/sql"
	_ "github.com/Go-SQL-Driver/MySQL"
	l4g "code.google.com/p/log4go"
)

var dbCon *sql.DB


// Open/Close DB
func OpenDB(dbUser string, dbPassword string, dbProtocol string, dbHost string, dbPort string, dbName string) {
	// Connect to database
	mysqlDsn := dbUser+":"+dbPassword+"@"+dbProtocol+"("+dbHost+":"+dbPort+")/"+dbName
	var err error
	dbCon, err = sql.Open("mysql", mysqlDsn)
	if err != nil {
		l4g.Crashf("could not connect to mysql database with DSN %v: %v\n", mysqlDsn, err)
	}
}
func CloseDB() {
	dbCon.Close()
}


// Get/Set Config
func DbGetConfig(key string) (val string, err error) {
	var valNS sql.NullString
	err = dbCon.QueryRow("SELECT `val` FROM `config` WHERE `key` = '"+key+"'").Scan(&valNS)
	if err != nil {
		log.Logf(l4g.ERROR, "dbGetConfig: SELECT unsuccessful for [key=%v]: %v", key, err)
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


// Get/Set Activity
func DbGetActivity(key string) (val string, err error) {
	var valNS sql.NullString
	err = dbCon.QueryRow("SELECT `val` FROM `activity` WHERE `key` = '"+key+"'").Scan(&valNS)
	if err != nil {
		log.Logf(l4g.ERROR, "dbGetActivity: SELECT unsuccessful for [key=%v]: %v", key, err)
		return
	}
	if valNS.Valid {
		val = valNS.String
	} else {
		// null string
		err = fmt.Errorf("dbGetActivity got NULL value for key %v", key)
	}
	return
}
