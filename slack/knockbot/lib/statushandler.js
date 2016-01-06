'use strict';

// Use this to get the time until the Hunt starts / time since it started
var HuntTime = require('./hunttime');

var StatusHandler = function Constructor(knockbot) {
    this.knockbot = knockbot;
};

StatusHandler.prototype.start = function() {
};

StatusHandler.prototype.canRespond = function(channel, message_text) {
    return message_text.indexOf('status') != -1;
};

StatusHandler.prototype.produceResponse = function(channel, message_text) {
    var text = '';

    var pbc = this.knockbot.pbc;

    text += (new HuntTime()).prettyTimeUntilHunt() + '\n';
    text += pbc.string_puzzle_status();

    return text;
};

module.exports = StatusHandler;
