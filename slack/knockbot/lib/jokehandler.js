'use strict';

var JokeHandler = function Constructor(knockbot) {
    this.knockbot = knockbot;
};

JokeHandler.prototype.start = function() {
};

JokeHandler.prototype.canRespond = function(message) {
    var message_text = message.text.toLowerCase();
    return message_text.indexOf('pod bay doors') != -1;
};

JokeHandler.prototype.produceResponse = function(message) {
    var user = this.knockbot._userFromId(message.user);
    return "I can't do that, " + user.name + ".";
};

module.exports = JokeHandler;
