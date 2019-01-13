package bigjimmybot

import (
	l4g "code.google.com/p/log4go"
	"fmt"
	"github.com/nlopes/slack"
	"regexp"
	"strings"
	"sync"
)

var slackApi *slack.Client

var slackChannelIds map[string]string // maps lowercased channel name to channel id
var slackChannelIds_lock sync.RWMutex

var slackIdsByName map[string]string // maps lowercased username to slack id
var slackIdsByName_lock sync.RWMutex
var slackIdsByRealName map[string]string // maps real name to slack id
var slackIdsByRealName_lock sync.RWMutex

var slackUserNamesById map[string]string
var slackUserNamesById_lock sync.RWMutex
var slackUserRealNamesById map[string]string
var slackUserRealNamesById_lock sync.RWMutex
var slackChannelNames map[string]string
var slackChannelNames_lock sync.RWMutex

var slackBigjimmyChannelId string
var slackGeneralChannelId string

var slackBigjimmyBotUserId string
var slackDebugUserId string
var slackDebugDirectMessageId string

var whitespaceRe *regexp.Regexp
var nonAZRe *regexp.Regexp

var slackReady bool

type SlackMessage struct {
	Id   string
	Text string
}

var slackMessages chan *SlackMessage
var slackDirectMessages chan *SlackMessage

func init() {
	// maps for matching slack user based on jcbarret's perl code
	slackIdsByName = make(map[string]string, 1000)
	slackIdsByRealName = make(map[string]string, 1000)
	slackChannelIds = make(map[string]string, 100)

	// maps for looking up slack IDs to get names
	slackUserNamesById = make(map[string]string, 1000)
	slackUserRealNamesById = make(map[string]string, 1000)
	slackChannelNames = make(map[string]string, 100)

	// initialise regexps for user matching
	whitespaceRe = regexp.MustCompile("[[:space:]]")
	nonAZRe = regexp.MustCompile("[^a-z]")
}

func SlackBot(slackToken string) (err error) {
	log.Logf(l4g.TRACE, "SlackBot(slackToken=%v)", slackToken)

	// create slack API
	slackApi = slack.New(slackToken)

	// TODO attach slack to logger with SetLogger

	// load initial slack users
	err = updateSlackUsers()
	if err != nil {
		log.Logf(l4g.ERROR, "SlackBot: failed to update slack users: %v (EXITING SLACKBOT)", err)
		return
	}

	// set my own id
	var ok bool
	slackIdsByName_lock.RLock()
	slackBigjimmyBotUserId, ok = slackIdsByName["slackapiuser"]
	slackIdsByName_lock.RUnlock()
	if !ok {
		log.Logf(l4g.ERROR, "SlackBot: failed to get slack id for bigjimmybot: %v (EXITING SLACKBOT)", err)
		return
	}

	// get channels
	err = updateSlackChannels()
	if err != nil {
		log.Logf(l4g.ERROR, "SlackBot: failed to update channels: %v (EXITING SLACKBOT)", err)
		return
	}

	// get general channel
	slackGeneralChannelId, err = GetSlackIdForChannel("general")
	if err != nil {
		log.Logf(l4g.ERROR, "SlackBot: failed to update channels: %v (EXITING SLACKBOT)", err)
		return
	}

	// get bigjimmy channel
	slackBigjimmyChannelId, err = GetSlackIdForChannel("puzzleboss-tech")
	if err != nil {
		log.Logf(l4g.ERROR, "SlackBot: failed to update channels: %v (EXITING SLACKBOT)", err)
		return
	}

	// connect to real-time messaging (RTM)
	rtm := slackApi.NewRTM()

	// direct message channel to jrandall for debugging
	slackIdsByName_lock.RLock()
	slackDebugUserId, ok = slackIdsByName["jrandall"] // todo make this an option
	slackIdsByName_lock.RUnlock()
	if !ok {
		log.Logf(l4g.ERROR, "SlackBot: failed to get slack id for jrandall: %v (EXITING SLACKBOT)", err)
		return
	}
	_, _, slackDebugDirectMessageId, err = rtm.OpenIMChannel(slackDebugUserId)
	if err != nil {
		log.Logf(l4g.ERROR, "SlackBot: failed to open an IM channel to id %v: %v (EXITING SLACKBOT)", slackDebugUserId, err)
		return
	}

	// start a goroutine to manage the RTM connection
	go rtm.ManageConnection()

	slackMessages = make(chan *SlackMessage, 10)
	slackDirectMessages = make(chan *SlackMessage, 10)
	go handleMessages(slackMessages, slackDirectMessages, rtm)

	slackReady = true

	log.Logf(l4g.INFO, "SlackBot: telling the world I'm back in action")
	SendSlackChannelMessage("puzzleboss-tech", "I'm back in action!")
	SendSlackUserMessage("jrandall", "Hello Master, I'm back in action!")

	return
}

func SendSlackChannelMessage(channel string, text string) {
	if !slackReady {
		log.Logf(l4g.WARNING, "SendSlackChannelMessage: slack not ready yet, cannot send: [%v] to [%v]", text, channel)
		return
	}
	// get channel id for message
	channelId, err := GetSlackIdForChannel(channel)
	if err != nil {
		log.Logf(l4g.ERROR, "RelayMessage: failed to get channel id for %v", channel)
		return
	}

	slackMessages <- &SlackMessage{Id: channelId, Text: text}
	return
}

func SendSlackUserMessage(user string, text string) {
	if !slackReady {
		log.Logf(l4g.WARNING, "SendSlackChannelMessage: slack not ready yet, cannot send: [%v] to [%v]", text, user)
		return
	}
	// get user id for message
	userId, err := GetSlackIdForSolver(&Solver{Name: user, FullName: user, Puzz: "", Id: ""}) // FIXME HACK
	if err != nil {
		log.Logf(l4g.ERROR, "RelayMessage: failed to get slack id for %v", user)
		return
	}

	slackDirectMessages <- &SlackMessage{Id: userId, Text: text}
	return
}

func SendSlackSolverMessage(solver *Solver, text string) {
	if !slackReady {
		log.Logf(l4g.WARNING, "SendSlackChannelMessage: slack not ready yet, cannot send: [%v] to [%v]", text, solver)
		return
	}
	// get user id for message
	userId, err := GetSlackIdForSolver(solver)
	if err != nil {
		log.Logf(l4g.ERROR, "RelayMessage: failed to get slack id for %v", solver)
		return
	}

	slackDirectMessages <- &SlackMessage{Id: userId, Text: text}
	return
}

func handleMessages(incomingSlackMessages chan *SlackMessage, incomingSlackDirectMessages chan *SlackMessage, rtm *slack.RTM) {
RTMLoop:
	for {
		select {
		case msg := <-rtm.IncomingEvents:
			log.Logf(l4g.DEBUG, "handleMessages: Event Received of type %v", msg.Type)
			switch ev := msg.Data.(type) {
			case *slack.HelloEvent:
				// Ignore hello
				log.Logf(l4g.TRACE, "handleMessages: HelloEvent")
				//rtm.SendMessage(rtm.NewOutgoingMessage("I'm back in action!", slackBigjimmyChannelId))

			case *slack.ConnectingEvent:
				log.Logf(l4g.TRACE, "handleMessages: Connecting. Attempt=%v ConnectionCount=%v", ev.Attempt, ev.ConnectionCount)

			case *slack.ConnectedEvent:
				log.Logf(l4g.TRACE, "handleMessages: Connected. Info=%v ConnectionCount=%v", ev.Info, ev.ConnectionCount)

			case *slack.DisconnectedEvent:
				log.Logf(l4g.TRACE, "handleMessages: Disconnected. Intentional=%v", ev.Intentional)

			case *slack.MessageEvent:
				log.Logf(l4g.TRACE, "handleMessages: Message: %+v\n", ev)
				realName, err := GetSlackUserRealNameForId(ev.User)
				if err != nil {
					log.Logf(l4g.ERROR, "SlackBOT RTMLoop: failed to get slack user real name for id %v: %v", ev.User, err)
					continue RTMLoop
				}
				channel, err := GetSlackChannelForId(ev.Channel)
				if err != nil {
					log.Logf(l4g.ERROR, "SlackBOT RTMLoop: failed to get slack channel name for id %v: %v", ev.Channel, err)
					continue RTMLoop
				}
				// TODO process user ids in Text e.g. "<@U3R79A0FN>" and replace with real name
				log.Logf(l4g.INFO, "SlackBOT RTMLoop: MESSAGE from %v on channel %v: %v", realName, channel, ev.Text)

			case *slack.PresenceChangeEvent:
				log.Logf(l4g.TRACE, "handleMessages: Presence Change: %v\n", ev)

			case *slack.LatencyReport:
				log.Logf(l4g.TRACE, "handleMessages: Current latency: %v\n", ev.Value)

			case *slack.RTMError:
				log.Logf(l4g.WARNING, "handleMessages: RTM Error: %s\n", ev.Error())

			case *slack.InvalidAuthEvent:
				log.Logf(l4g.ERROR, "HandleMessage: slack authentication error: %v", ev)
				break RTMLoop

			default:
				// Ignore other events..
				log.Logf(l4g.DEBUG, "handleMessages: Unexpected: %v\n", msg.Data)
			}
		case msg := <-incomingSlackMessages:
			log.Logf(l4g.TRACE, "handleMessages: sending message to %v: %v", msg.Id, msg.Text)
//			rtm.SendMessage(rtm.NewOutgoingMessage(msg.Text, msg.Id))
			rtm.SendMessage(rtm.NewOutgoingMessage(fmt.Sprintf("SLACKBOT DEBUG to: %v %v", msg.Id, msg.Text), slackDebugDirectMessageId))
		case msg := <-incomingSlackDirectMessages:
			log.Logf(l4g.TRACE, "handleMessages: sending direct message to %v: %v", msg.Id, msg.Text)
			_, _, id, err := rtm.OpenIMChannel(msg.Id)
			if err != nil {
				log.Logf(l4g.ERROR, "handleMessages: failed to open an IM channel to id %v: %v", msg.Id, err)
			}
			log.Logf(l4g.TRACE, "handleMessages: sending IM message to id %v for user id %v", id, msg.Id)
//			rtm.SendMessage(rtm.NewOutgoingMessage(msg.Text, id))
			rtm.SendMessage(rtm.NewOutgoingMessage(fmt.Sprintf("SLACKBOT DEBUG to: %v %v", id, msg.Text), slackDebugDirectMessageId))		}
	}
	log.Logf(l4g.ERROR, "HandleMessage: exiting (NOT HANDLING SLACK RTM ANYMORE!)")
	return
}

func updateSlackChannels() (err error) {
	log.Logf(l4g.TRACE, "updateSlackChannels()")
	slackChannels, err := slackApi.GetChannels(true)
	if err != nil {
		log.Logf(l4g.ERROR, "updateSlackChannels: failed to get slackChannels: %v", err)
		return
	}
	slackChannelIds_lock.Lock()
	slackChannelNames_lock.Lock()
	defer slackChannelIds_lock.Unlock()
	defer slackChannelNames_lock.Unlock()
	for _, slackChannel := range slackChannels {
		log.Logf(l4g.TRACE, "updateSlackChannels: have channel ID: %s, Name: %s", slackChannel.ID, slackChannel.Name)

		var ok bool
		if _, ok = slackChannelIds[strings.ToLower(slackChannel.Name)]; !ok {
			nameLowerCase := strings.ToLower(slackChannel.Name)
			slackChannelIds[nameLowerCase] = slackChannel.ID
			slackChannelNames[slackChannel.ID] = nameLowerCase
		}
	}
	return
}

func updateSlackUsers() (err error) {
	log.Logf(l4g.TRACE, "updateSlackUsers()")
	slackUsers, err := slackApi.GetUsers()
	if err != nil {
		log.Logf(l4g.ERROR, "updateSlackUsers: failed to get slackUsers: %v", err)
		return
	}
	slackIdsByName_lock.Lock()
	defer slackIdsByName_lock.Unlock()

	slackIdsByRealName_lock.Lock()
	defer slackIdsByRealName_lock.Unlock()

	slackUserNamesById_lock.Lock()
	defer slackUserNamesById_lock.Unlock()

	slackUserRealNamesById_lock.Lock()
	defer slackUserRealNamesById_lock.Unlock()

	for _, slackUser := range slackUsers {
		log.Logf(l4g.TRACE, "updateSlackUsers: have slack user ID: %s, Name: %s RealName: %s", slackUser.ID, slackUser.Name, slackUser.RealName)
		var ok bool
		userNameLowerCase := strings.ToLower(slackUser.Name)
		if _, ok = slackUserNamesById[slackUser.ID]; !ok {
			slackUserNamesById[slackUser.ID] = slackUser.Name
		}
		if _, ok = slackUserRealNamesById[slackUser.ID]; !ok {
			slackUserRealNamesById[slackUser.ID] = slackUser.RealName
		}
		if _, ok = slackIdsByName[userNameLowerCase]; !ok {
			slackIdsByName[userNameLowerCase] = slackUser.ID
		}
		if _, ok = slackIdsByRealName[slackUser.RealName]; !ok {
			slackIdsByRealName[slackUser.RealName] = slackUser.ID
		}
		slackUserRealNameLowerCase := strings.ToLower(slackUser.RealName)
		if _, ok = slackIdsByRealName[slackUserRealNameLowerCase]; !ok {
			slackIdsByRealName[slackUserRealNameLowerCase] = slackUser.ID
		}
		slackUserRealNameLowerCaseNoSpaces := whitespaceRe.ReplaceAllLiteralString(slackUserRealNameLowerCase, "")
		if _, ok = slackIdsByRealName[slackUserRealNameLowerCaseNoSpaces]; !ok {
			slackIdsByRealName[slackUserRealNameLowerCaseNoSpaces] = slackUser.ID
		}
		slackUserRealNameLowerCaseNoSpacesAZOnly := nonAZRe.ReplaceAllLiteralString(slackUserRealNameLowerCaseNoSpaces, "")
		if _, ok = slackIdsByRealName[slackUserRealNameLowerCaseNoSpacesAZOnly]; !ok {
			slackIdsByRealName[slackUserRealNameLowerCaseNoSpacesAZOnly] = slackUser.ID
		}
	}
	return
}

func GetSlackIdForChannel(channel string) (slackId string, err error) {
	if !slackReady {
		log.Logf(l4g.WARNING, "GetSlackIdForChannel: slack not ready yet, cannot get id for: %v", channel)
		return
	}
	slackChannelIds_lock.RLock()
	defer slackChannelIds_lock.RUnlock()
	var ok bool
	if slackId, ok = slackChannelIds[channel]; !ok {
		err = fmt.Errorf("failed to get channel id for channel %v", channel)
	}
	return
}

func GetSlackChannelForId(id string) (channel string, err error) {
	if !slackReady {
		log.Logf(l4g.WARNING, "GetSlackChannelForId: slack not ready yet, cannot get channel for: %v", id)
		return
	}
	slackChannelNames_lock.RLock()
	defer slackChannelNames_lock.RUnlock()
	var ok bool
	if channel, ok = slackChannelNames[id]; !ok {
		err = fmt.Errorf("failed to get channel name for channel id %v", id)
	}
	return
}

func GetSlackUserNameForId(id string) (userName string, err error) {
	if !slackReady {
		log.Logf(l4g.WARNING, "GetSlackUserNameForId: slack not ready yet, cannot get name for: %v", id)
		return
	}
	slackUserNamesById_lock.RLock()
	defer slackUserNamesById_lock.RUnlock()
	var ok bool
	if userName, ok = slackUserNamesById[id]; !ok {
		err = fmt.Errorf("failed to get user name for user id %v", id)
	}
	return
}

func GetSlackUserRealNameForId(id string) (userRealName string, err error) {
	if !slackReady {
		log.Logf(l4g.WARNING, "GetSlackUserRealNameForId: slack not ready yet, cannot get real name for: %v", id)
		return
	}
	slackUserRealNamesById_lock.RLock()
	defer slackUserRealNamesById_lock.RUnlock()
	var ok bool
	if userRealName, ok = slackUserRealNamesById[id]; !ok {
		err = fmt.Errorf("failed to get user real name for user id %v", id)
	}
	return
}

func GetSlackIdForSolver(solver *Solver) (slackId string, err error) {
	if !slackReady {
		log.Logf(l4g.WARNING, "GetSlackIdForSolver: slack not ready yet, cannot get id for solver: %v", solver)
		return
	}
	slackId, err = getSlackIdForSolver(solver)
	if err != nil {
		// we did not find the slack id, try updating slack users and trying again
		updateSlackUsers()
		slackId, err = getSlackIdForSolver(solver)
	}
	return
}

func getSlackIdForSolver(solver *Solver) (slackId string, err error) {
	slackIdsByName_lock.RLock()
	defer slackIdsByName_lock.RUnlock()
	var ok bool
	if slackId, ok = slackIdsByName[solver.Name]; ok {
		log.Logf(l4g.TRACE, "GetSlackIdForSolver(%v) found slack ID by unmodified solver.Name: %v", solver, slackId)
		return
	}

	nameLowerCase := strings.ToLower(solver.Name)
	if slackId, ok = slackIdsByName[nameLowerCase]; ok {
		log.Logf(l4g.TRACE, "GetSlackIdForSolver(%v) found slack ID by nameLowerCase (%v): %v", solver, nameLowerCase, slackId)
		return
	}

	slackIdsByRealName_lock.RLock()
	defer slackIdsByRealName_lock.RUnlock()
	fullNameLowerCase := strings.ToLower(solver.FullName)
	if slackId, ok = slackIdsByRealName[fullNameLowerCase]; ok {
		log.Logf(l4g.TRACE, "GetSlackIdForSolver(%v) found slack ID by fullNameLowerCase (%v): %v", solver, fullNameLowerCase, slackId)
		return
	}

	fullNameLowerCaseNoSpaces := whitespaceRe.ReplaceAllLiteralString(fullNameLowerCase, "")
	if slackId, ok = slackIdsByRealName[fullNameLowerCaseNoSpaces]; ok {
		log.Logf(l4g.TRACE, "GetSlackIdForSolver(%v) found slack ID by fullNameLowerCaseNoSpaces (%v): %v", solver, fullNameLowerCaseNoSpaces, slackId)
		return
	}

	fullNameLowerCaseNoSpacesAZOnly := nonAZRe.ReplaceAllLiteralString(fullNameLowerCaseNoSpaces, "")
	if slackId, ok = slackIdsByRealName[fullNameLowerCaseNoSpacesAZOnly]; ok {
		log.Logf(l4g.TRACE, "GetSlackIdForSolver(%v) found slack ID by fullNameLowerCaseNoSpacesAZOnly (%v): %v", solver, fullNameLowerCaseNoSpacesAZOnly, slackId)
		return
	}

	err = fmt.Errorf("could not find slack id for solver: %v (%v)", solver.Name, solver.FullName)
	return
}

// TODO GetSolverForSlackUser
