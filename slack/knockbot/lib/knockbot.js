'use strict';

var Bot = require('slackbots');
var util = require('util');

var StatusHandler = require('./statushandler');
var HuntTime = require('./hunttime');
var HelpHandler = require('./helphandler');
var AnnounceHandler = require('./announcehandler');
var LinksHandler = require('./linkshandler');
var EventHandler = require('./eventhandler');
var JokeHandler = require('./jokehandler');
var PBConnect = require('./pbconnect');

/*
 * Setup
 */

// Initialize KnockBot
var KnockBot = function Constructor(settings) {
    this.settings = settings;

    // Bot's username
    this.settings.name = this.settings.name.toLowerCase();

    this.post_params = {as_user: true};

    // Copy of the user data
    this.user = null;

    this.knownUserIds = null;
    this.knownBotIds = null;

    // List of handler objects
    this.handlers = null;

    // PB connection
    this.pbc = null;
};

// Inherits methods and properties from the Bot constructor
util.inherits(KnockBot, Bot);

// Run the bot
KnockBot.prototype.run = function () {
    KnockBot.super_.call(this, this.settings);

    this._registerHandlers();

    this.on('start', this._onStart);
    this.on('message', this._onMessage);

    // Connect to PB
    this.pbc = new PBConnect();
    this.pbc.connect();
};

// On Start
KnockBot.prototype._onStart = function () {
    this._identifyBotUser(); // Identify self

    // Iterate over the handlers, call start()
    for (var i = 0; i < this.handlers.length; i++) {
        this.handlers[i].start();
    }

};

/*
 * Register Handlers
 */

 KnockBot.prototype._registerHandlers = function () {
    this.handlers = [
        new StatusHandler(this),
        new HuntTime(this),
        new HelpHandler(this),
        new LinksHandler(this),
        new EventHandler(this),
        new AnnounceHandler(this),
        new JokeHandler(this)
        ];
 }

/*
 * User information
 */

// Identify this bot
KnockBot.prototype._identifyBotUser = function () {
    var self = this;
    this.user = this.users.filter(function (user) {
        return user.name === self.name;
    })[0];
};

// Keep a list (in memory) of bots and users
KnockBot.prototype._createUserList = function () {    
    // Create a list of known user IDs
    this.knownUserIds = this.users.map(function (user) {
        return user.id;
    });

    // Create a list of known bot IDs
    var botlist = this.users.filter(function (user) {
        return user.is_bot || user.name == 'slackbot';
    });
    this.knownBotIds = botlist.map(function (user) {
        return user.id;
    });
};

KnockBot.prototype._userFromId = function (userId) {
    return this.users.filter(function (user) {
        return user.id == userId;
    })[0];
};

// True if the message is from this bot
KnockBot.prototype._isFromThisBot = function (message) {
    return message.user === this.user.id;
};

// True if the message is from a bot
KnockBot.prototype._isFromABot = function (message) {
    return this._userIsABot(message.user);
};

// True if user ID belongs to a bot
KnockBot.prototype._userIsABot = function (userId) {
    // Create the user lists if they don't exist or
    // if the userId is unknown
    if (this.knownUserIds == null || this.knownBotIds == null || this.knownUserIds.indexOf(userId) == -1) {
        this._createUserList();
    }

    return this.knownBotIds.indexOf(userId) != -1;
};

/*
 * Handle chat messages
 */

// True if this is a chat message
KnockBot.prototype._isChatMessage = function (message) {
    return message.type === 'message' && Boolean(message.text);
};

// True if this is in a channel (or group)
KnockBot.prototype._isChannelMessage = function (message) {
    return typeof message.channel === 'string' &&
        (message.channel[0] == 'C' || message.channel[0] == 'G');
};

// True if this is a direct message
KnockBot.prototype._isDirectMessage = function (message) {
    return typeof message.channel === 'string' &&
        (message.channel[0] == 'D');    
};

// Get a channel by name
KnockBot.prototype._getChannelByName = function (channel_name) {
    var channel_list = [].concat(this.channels, this.groups, this.ims);

    // Filter the channel list to the one we want
    return channel_list.filter(function (item) {
            return item.name == channel_name;
    })[0];
};

// True if this bot's user ID appears after '@'
KnockBot.prototype._mentionedKnockbot = function (message) {
    return message.text.indexOf('@' + this.user.id) != -1;
};

// Receive a message and decide if it is appropriate to respond
KnockBot.prototype._onMessage = function (message) {

    // Only respond to chat messages,
    // No typing indicators, pings, etc.
    if (!this._isChatMessage(message)) {
        return;
    }

    // Don't respond to other bots
    if (this._isFromABot(message)) {
        return;
    }

    // Respond to in-channel @mentions or direct messages
    if ((this._isChannelMessage(message) && this._mentionedKnockbot(message)) ||
        this._isDirectMessage(message))
    {
        this._processMessage(message);
    }
};

// Process a message by calculating the response and sending it appropriately
KnockBot.prototype._processMessage = function (message) {
    var response = null;
    
    // Iterate over the handlers
    for (var i = 0; i < this.handlers.length; i++) {

        // Skip if this handler cannot produce a response
        if (!this.handlers[i].canRespond(message)) {
            continue;
        }

        // Get the response from the handler
        response = this.handlers[i].produceResponse(message);
        
        // Stop at the first response
        if (response !== null) {
            break;
        }
    }

    // Send a response
    if (response !== null) {
        this.postMessage(message.channel, response, this.post_params);
    }
};

// Post a new message to a named channel
KnockBot.prototype.postNewMessage = function (channel_name, message_text) {
    this.postMessageToChannel(channel_name, message_text, this.post_params);
};

module.exports = KnockBot;
