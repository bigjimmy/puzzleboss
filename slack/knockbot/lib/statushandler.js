'use strict';

// Use this to get the time until the Hunt starts / time since it started
var HuntTime = require('./hunttime');

var StatusHandler = function Constructor(knockbot) {
    this.knockbot = knockbot;
};

StatusHandler.prototype.start = function() {
};

StatusHandler.prototype.canRespond = function(message) {
    var message_text = message.text.toLowerCase();
    return (message_text.indexOf('status') != -1) ||
           (message_text.indexOf('rounds') != -1) ||
           (this.knockbot.pbc.message_contains_puzzle_name(message_text)) ||
           (this.knockbot.pbc.message_contains_round_name(message_text));
};

StatusHandler.prototype.produceResponse = function(message) {
    var text = '';
    var message_text = message.text.toLowerCase();

    var pbc = this.knockbot.pbc;

    if (pbc.message_contains_puzzle_name(message_text)) {

        // Give information about a specific puzzle
        var id = pbc.guess_puzzle_id(message.text);
        text += pbc.puzzle_status_string(id);

    } else if (pbc.message_contains_round_name(message_text)) {

        // Give information about a specific puzzle
        var id = pbc.guess_round_id(message.text);
        text += pbc.round_status_string(id);

    } else if (message_text.indexOf('rounds') != -1) {

        text += pbc.all_rounds_status_string();

    } else {

        // Just give a general Hunt status update
        text += (new HuntTime()).prettyTimeUntilHunt() + '\n';
        text += pbc.hunt_status_string();

    }

    return text;
};

module.exports = StatusHandler;
