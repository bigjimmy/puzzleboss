'use strict';

var huntstart = new Date("Jan 15 2016 12:00:00 GMT-0500 (EST)");
var general_channel = 'general';

// For testing
// var huntstart = new Date();
// huntstart = new Date(huntstart.getTime() + (5 * 1000) + (10 * 24 * 60 * 60 * 1000));
// console.log(huntstart.toString());

var HuntTime = function Constructor(knockbot) {
    this.knockbot = knockbot;
};

HuntTime.prototype.start = function() {
    this.queueAnnouncements();
};

HuntTime.prototype.queueAnnouncements = function() {
    var self = this;
    function helper(minutes_before) {
        
        var now = (new Date()).getTime();
        var ms_before = minutes_before * 60 * 1000;
        var target_time = huntstart - ms_before - 100; // 100ms early
        var timeout = target_time - now;
        
        if (timeout > 0) {
            setTimeout(announceTimeUntilHunt, timeout, self.knockbot);
        }        
    }

    // Once a day, at noon
    for (var days_before = 1; days_before <= 10; days_before++) {
        var minutes_before = days_before * 24 * 60;
        helper(minutes_before);
    }

    // Every six hours
    for (var hours_before = 6; hours_before < 24; hours_before += 6) {
        var minutes_before = hours_before * 60;
        helper(minutes_before);
    }

    // Every hour
    for (var hours_before = 1; hours_before < 6; hours_before++) {
        var minutes_before = hours_before * 60;
        helper(minutes_before);
    }

    // Every fifteen minutes
    for (var minutes_before = 0; minutes_before < 60; minutes_before += 15) {
        helper(minutes_before);
    }    
};

function announceTimeUntilHunt(knockbot) {
    knockbot.postNewMessage(general_channel, prettyTimeUntilHunt());
}

// Respond to 'time' or 'when'
HuntTime.prototype.canRespond = function(channel, message_text) {
    return message_text.indexOf('time') != -1 || message_text.indexOf('when') != -1 || message_text.indexOf('how long') != -1;
};

// Tell them
HuntTime.prototype.produceResponse = function(channel, message_text) {
    return prettyTimeUntilHunt();
};

function prettyTimeUntilHunt() {
    // Get the time difference
    var now = new Date();
    var o = splitTime(huntstart - now);


    if (o.days > 1) {
        return spelledTime(o.days, 'day');
    }

    if (Math.abs(o.hours) >= 1) {
        return spelledTime(o.hours, 'hour');
    }

    if (Math.abs(o.minutes) > 1) {
        return spelledTime(o.minutes, 'minute');
    }

    if (Math.abs(o.minutes) <= 1) {
        return 'Hunt is starting!';
    }

    return null;
};

HuntTime.prototype.prettyTimeUntilHunt = function() {
    return prettyTimeUntilHunt();
};

function splitTime(ms) {
    var o = new Object()
    o.minutes = ms / 1000 / 60;
    o.hours = o.minutes / 60;
    o.days = o.hours / 24;
    return o;
}

function spelledTime(number, noun) {

    var print_number = Math.round(Math.abs(number));

    var text = print_number + ' ' + noun;
    if (print_number > 1) {
        text += 's';
    }

    if (number > 0) {
        text += ' until Hunt!';
    } else {
        text += ' since Hunt started.';
    }
    return text;
}

module.exports = HuntTime;
