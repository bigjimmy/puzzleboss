'use strict';

//var huntstart = new Date("Jan 15 2016 12:00:00 GMT-0500 (EST)");
//var huntstart = new Date("Jan 13 2017 14:00:00 GMT-0500 (EST)");
var huntstart = new Date("Jan 12 2018 12:00:00 GMT-0500 (EST)");
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
        var target_time = huntstart - ms_before;
        target_time += 2 * 1000; // 2 second delay
        var timeout = target_time - now;
        
        if (timeout > 0) {
            setTimeout(announceTimeUntilHunt, timeout, self.knockbot);
        }        
    }

    // 1, 2, and 3 days before
    helper(3 * 24 * 60);
    helper(2 * 24 * 60);
    helper(1 * 24 * 60);

    // 1, 2, 6, 12, and 18 hours before
    helper(18 * 60);
    helper(12 * 60);
    helper(6 * 60);
    helper(2 * 60);
    helper(1 * 60);

    // 0 and 30 minutes before
    helper(30);
    helper(0);
};

function announceTimeUntilHunt(knockbot) {
    knockbot.postNewMessage(general_channel, prettyTimeUntilHunt());
}

// Respond to 'time' or 'when'
HuntTime.prototype.canRespond = function(message) {
    var message_text = message.text.toLowerCase();
    return message_text.indexOf('time') != -1 ||
           message_text.indexOf('when') != -1 ||
           message_text.indexOf('how long') != -1;
};

// Tell them
HuntTime.prototype.produceResponse = function(message) {
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

    //return 'The coin was found by SETEC on Sunday at 6:53pm!\nHunt was 53 hours long.\n';

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
