'use strict';

var LinksHandler = function Constructor(knockbot) {
};

LinksHandler.prototype.start = function() {
};

LinksHandler.prototype.canRespond = function(message) {
    var message_text = message.text.toLowerCase();
    return message_text.indexOf('link') != -1;
};

LinksHandler.prototype.produceResponse = function(message) {
    return "URL is <https://head-hunters.org|head-hunters.org>" + 
           " login is cyrilcs, password is updatetetazooglounge\n" +
           "Wiki: <https://wind-up-birds.org|wind-up-birds.org>\n" +
           "<https://wind-up-birds.org/puzzleboss/bin/overview.pl|PuzzleBoss overview>";
};

module.exports = LinksHandler;
