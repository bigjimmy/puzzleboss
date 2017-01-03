'use strict';

var general_channel = 'general';

var AnnounceHandler = function Constructor(knockbot) {
    this.knockbot = knockbot;
};

AnnounceHandler.prototype.start = function() {
};

AnnounceHandler.prototype.canRespond = function(message) {
    var message_text = message.text.toLowerCase();
    return (message_text.indexOf('announce ') == 0) &&
           this.knockbot._isDirectMessage(message);
};

AnnounceHandler.prototype.produceResponse = function(message) {
    var message_text = message.text.toLowerCase();
    if (message_text.indexOf('announce ') == 0) {
        var announcement = message.text.substring('announce '.length);
        this.knockbot.postNewMessage(general_channel, announcement);
    }
    return null;
};

module.exports = AnnounceHandler;
