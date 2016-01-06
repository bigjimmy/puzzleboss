'use strict';

var HelpHandler = function Constructor(knockbot) {
};

HelpHandler.prototype.start = function() {
};

HelpHandler.prototype.canRespond = function(channel, message_text) {
    return message_text.indexOf('help') != -1;
};

HelpHandler.prototype.produceResponse = function(channel, message_text) {
    return "Hi, I'm KnockBot!\n" +
           "I can tell you the 'status' of the Hunt or the 'time' since Hunt started.";
};

module.exports = HelpHandler;
