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
	log = extLog
}

var httpRestReqLimiter chan int
func SetRestReqLimiter(extRestReqLimiter chan int) {
	httpRestReqLimiter = extRestReqLimiter
}

var pbRestUri string
func SetPbRestUri(extPbRestUri string) {
	pbRestUri = extPbRestUri
}

