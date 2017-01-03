'use strict';

var HelpHandler = function Constructor(knockbot) {
};

HelpHandler.prototype.start = function() {
};

HelpHandler.prototype.canRespond = function(message) {
    var message_text = message.text.toLowerCase();
    return message_text.indexOf('help') != -1;
};

HelpHandler.prototype.produceResponse = function(message) {
    return "If you need *help*, I can tell you the *status* of the Hunt, about all the *rounds*," + 
           " the *time* since Hunt started, and a list of important *links*. " +
           "Or, just ask me about a specific round or puzzle.\n" +
           "Feel free to DM me or */invite* me to a channel.";
};

module.exports = HelpHandler;
