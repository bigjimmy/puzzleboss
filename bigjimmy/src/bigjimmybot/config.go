package bigjimmybot

import (
	"crypto/tls"
	"net/http"
	l4g "code.google.com/p/log4go"
)

var httpClient *http.Client
func init() {
	// Initialize http transport
	tr := &http.Transport{
		TLSClientConfig:    &tls.Config{RootCAs: nil},
	}
	httpClient = &http.Client{Transport: tr}
}


var log l4g.Logger
func SetLog(extLog l4g.Logger) {
        extLog.Logf(l4g.TRACE, "SetLog(extLog=%v)\n", extLog)
	log = extLog
}

var httpRestReqLimiter chan int
func SetRestReqLimiter(extRestReqLimiter chan int) {
        log.Logf(l4g.TRACE, "SetRestReqLimiter(extRestReqLimiter=%v)\n", extRestReqLimiter)
	httpRestReqLimiter = extRestReqLimiter
}

var pbRestUri string
func SetPbRestUri(extPbRestUri string) {
        log.Logf(l4g.TRACE, "SetPbRestUri(extPbRestUri=%v)\n", extPbRestUri)
	pbRestUri = extPbRestUri
}

var huntFolderId string
func SetHuntFolderId (extHuntFolderId string) {
        log.Logf(l4g.TRACE, "SetHuntFolderId(extHuntFolderId=%v)\n", extHuntFolderId)
	huntFolderId = extHuntFolderId
}