'use strict';

var EventHandler = function Constructor(knockbot) {
};

EventHandler.prototype.start = function() {
};

EventHandler.prototype.canRespond = function(message) {
    var message_text = message.text.toLowerCase();
    return message_text.indexOf('event') != -1;
};

EventHandler.prototype.produceResponse = function(message) {
    return "Friday 9PM, 66-110, \"Adventures in Dreamland\"" + 
           " -- Send one or two adventurous people willing to perform in public.\n" +
           "Saturday 10AM, Lobdell, \"The Matrix\"" +
           " -- Send one solver to this co-operative solving event\n" +
           "Saturday 2PM, Sala de Puerto Rico, \"Escape from Mars\"" +
           " -- Send two people for a timed mini-puzzle event with word and logic puzzles.\n" +
           "Saturday 6PM, Lobdell, \"The Trivial Pursuits of Walter Mitty\"" + 
           " -- Send one team member who dreams of all manner of trivial pursuits";
};

module.exports = EventHandler;
