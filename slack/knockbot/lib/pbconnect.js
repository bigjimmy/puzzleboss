'use strict';

var refresh_rate = 20*1000; // Refresh from database every 20 seconds
var reconnect_rate = 2*60*1000; // Try to reconnect every two minutes

var mysql = require('mysql');

var PBConnect = function Constructor() {
    this.con = null;

    this.connection_options = {
        host: "localhost",
        port: "3306",
        user: process.env.PB_USERNAME,
        password: process.env.PB_PASSWORD
    };

    // Interval timer for data refresh
    this.refresh_interval = null;
    // Interval timer for DB reconnect
    this.reconnect_interval = null;

    // Copy of DB rows
    this.puzzle_view_rows = null;
    this.round_rows = null;
};

// Start an interval which repeatedly tries to connect to the database
PBConnect.prototype.connect = function() {
    //console.log('connect()');
    
    // Immediate connection attempt
    this.connect_database();

    // Create an interval to try reconnecting
    this.reconnect_interval = setInterval(
        function (self) {self.connect_database()},
        reconnect_rate, this);
};

// Attempt a DB connection
// If successful, stop trying to reconnect and start refreshing data
PBConnect.prototype.connect_database = function() {
    //console.log('connect_database()');

    var self = this;

    // First you need to create a connection to the db
    this.con = mysql.createConnection(this.connection_options);

    // What to do with a connection error
    this.con.on('error', function () {error_disconnect(self)});

    // Try to connect to the DB
    this.con.connect(function (err) {

        // Unable to connect
        if (err) {
            console.log('Error connecting to DB');
            return;
        }

        console.log('Connection established');

        // Stop trying to reconnect
        if (self.reconnect_interval) {
            clearInterval(self.reconnect_interval);
            self.reconnect_interval = null;
        }

        // Set up a continual data refresh
        self.continual_refresh();
    });
};

// Disconnect from the DB
PBConnect.prototype.disconnect = function() {

    // Stop trying to reconnect
    if (self.reconnect_interval) {
        clearInterval(self.reconnect_interval);
        self.reconnect_interval = null;
    }

    // Disconnect from the database
    this.con.end(function(err) {
        // The connection is terminated gracefully
        // Ensures all previously enqueued queries are still
        // before sending a COM_QUIT packet to the MySQL server.
    });
};

// What to do when losing the DB connection
function error_disconnect(self) {
    //console.log('error_disconnect()');

    // Stop trying to refresh the data
    if (self.refresh_interval) {
        clearInterval(self.refresh_interval);
        self.refresh_interval = null;
    }

    // Start trying to connect
    self.connect();

};

// Set an interval to refresh from the database
PBConnect.prototype.continual_refresh = function() {
    var self = this;
    refresh_status(self);
    this.refresh_interval = setInterval(refresh_status, refresh_rate, self);
};

// Grab data from the database
function refresh_status(self) {
    //console.log('refresh_status');

    self.con.query('SELECT * FROM puzzlebitch.puzzle_view', function (err, rows) {
        if (err) {
            console.log('Error reading puzzle_view from the DB');
            return;
        }
        self.puzzle_view_rows = rows;
    });

    self.con.query('SELECT * FROM puzzlebitch.round', function (err, rows) {
        if (err) {
            console.log('Error reading round from the DB');
            return;
        }
        self.round_rows = rows;
    });
};

// Return a string about the puzzle status
PBConnect.prototype.hunt_status_string = function() {
    var text = '';

    var puzzle_count = this.puzzle_view_rows.length;
    var round_count = this.round_rows.length;

    if (puzzle_count == 0 && round_count == 0)
        return 'No puzzles yet!';

    // Count the number of new, solved, and needs eyes puzzles
    var new_count = 0;
    var solved_count = 0;
    var eyes_count = 0;

    for (var r = 0; r < this.puzzle_view_rows.length; r++) {
        switch (this.puzzle_view_rows[r].status) {
            case 'New':
                new_count++;
                break;
            case 'Solved':
                solved_count++;
                break;
            case 'Needs eyes':
                eyes_count++;
                break;
            case 'Being worked':
            default:
        }
    };

    if (new_count > 0) {
        text += (new_count == 1) ? '1 new puzzle\n' : new_count + ' new puzzles\n';
    }

    if (eyes_count > 0) {
        text += (eyes_count == 1) ? '1 puzzle needs eyes\n' : eyes_count + ' puzzles need eyes\n';
    }
    
    text += 'Solved ' + solved_count + ' of ';
    text += (puzzle_count == 1) ? '1 puzzle' : puzzle_count + ' puzzles';
    text += (round_count == 1) ? ' across 1 round\n' : ' across ' + round_count + ' rounds\n';

    text += 'Check out the <https://wind-up-birds.org/puzzleboss/bin/overview.pl|PuzzleBoss overview>';

    return text;
};

PBConnect.prototype.guess_puzzle_id = function(message_text) {
    // Don't try if we have no data
    if (!this.puzzle_view_rows) {
        return null;
    }

    return guess_id(message_text, this.puzzle_view_rows);
};

function guess_id(message_text, search_array) {
    message_text = message_text.toLowerCase().replace(/\s+/g, '');

    var longest_length = 0;
    var longest_index = -1;
    for (var i = 0; i < search_array.length; i++) {
        var simple_name = search_array[i].name.toLowerCase().replace(/\s+/g, '');
        var common_length = longestCommonSubstring(message_text, simple_name);
        if (common_length >= longest_length) {
            longest_length = common_length;
            longest_index = i;
        }
    }
    if (longest_length >= 4) {
        return search_array[longest_index].id;
    }

    return null;  
}

PBConnect.prototype.message_contains_puzzle_name = function(message_text) {
    return (this.guess_puzzle_id(message_text) != null);
};

PBConnect.prototype.guess_round_id = function(message_text) {
    // Don't try if we have no data
    if (!this.round_rows) {
        return null;
    }

    return guess_id(message_text, this.round_rows);
};

PBConnect.prototype.message_contains_round_name = function(message_text) {
    return (this.guess_round_id(message_text) != null);
};

PBConnect.prototype.puzzle_status_string = function(id) {

    var text = '';

    // Find the puzzle row
    var puzzle = this.puzzle_view_rows.filter(function (row) {
        return row.id == id;
    })[0];

    // Shouldn't happen
    if (puzzle == null) {
        return ''
    }

    // Tell the status of the puzzle
    text += 'Puzzle "';
    text += (puzzle.puzzle_uri) ? '<' + puzzle.puzzle_uri + '|' + puzzle.name + '>' : puzzle.name;
    text += '" in round "' + puzzle.round + '" ';
    switch (puzzle.status) {
        case 'New':
            text += 'is new.';
            break;
        case 'Solved':
            text += 'has been solved.';
            break;
        case 'Needs eyes':
            text += 'needs eyes.';
            break;
        case 'Being worked':
            text += 'is being worked.';
            break;
        default:
            text += 'has status "' + puzzle.status + '".';
    }
    text += '\n';

    // Give the answer
    if (puzzle.answer) {
        text += 'The answer is ' + puzzle.answer + '.\n';
    }

    // Give some details about the solvers
    if (puzzle.solvers && puzzle.status != 'Solved') {
        var names = puzzle.solvers.replace(/,/g, ', ');;
        names = puzzle.solvers.replace(/,/g, ', ');
        text += 'Current solvers are: ' + names + '\n';
    }

    // Give some details about the locations
    if (puzzle.locations && puzzle.status != 'Solved') {
        var locs = puzzle.locations.replace(/,/g, ', ');;
        locs = puzzle.locations.replace(/,/g, ', ');
        text += 'Solving locations: ' + locs + '\n';
    }

    // If the PB has a comment
    if (puzzle.comments) {
        text += 'PB comment: ' + puzzle.comments + '\n';
    }

    // Give the google drive link
    if (puzzle.drive_uri && puzzle.status != 'Solved') {
        text += '(<' + puzzle.drive_uri + '|Spreadsheet>)\n';
    }

    return text;

};

PBConnect.prototype.round_status_string = function(id) {
    var text = '';

    var round = this.round_rows.filter(function (row) {
        return row.id == id;
    })[0];

    return this.round_status_string_helper(round);

};

PBConnect.prototype.all_rounds_status_string = function() {
    var text = '';
    var self = this;

    text += this.round_rows.map(function(round, i, a) {
        return self.round_status_string_helper(round);
    }).join('\n');

    text += '\nCheck out the <https://wind-up-birds.org/puzzleboss/bin/overview.pl|PuzzleBoss overview>';

    return text;

};

PBConnect.prototype.round_status_string_helper = function(round) {
    var text = '';

    text += 'Round ';
    text += round.drive_uri ? '<' + round.drive_uri + '|' + round.name + '>' : round.name;

    if (this.puzzle_view_rows) {
        var round_puzzles = this.puzzle_view_rows.filter(function (row) {
            return row.round == round.name;
        });

        var num_puzzles_solved = round_puzzles.filter(function (row) {
            return row.status == 'Solved';
        }).length;

        var num_puzzles_new = round_puzzles.filter(function (row) {
            return row.status == 'New';
        }).length;

        var num_puzzles_eyes = round_puzzles.filter(function (row) {
            return row.status == 'Needs eyes';
        }).length;

        text += ': ' + num_puzzles_solved + ' of ' + round_puzzles.length + ' ';
        text += round_puzzles.length == 1 ? 'puzzle' : 'puzzles';
        text += ' solved';

        if (num_puzzles_new > 0) {
            text += num_puzzles_new == 1 ? ', 1 new puzzle' : ', ' + num_puzzles_new + ' new puzzles';
        }

        if (num_puzzles_eyes > 0) {
            text += num_puzzles_eyes == 1 ? ', 1 puzzle needs eyes' : ', ' + num_puzzles_eyes + ' puzzles need eyes';
        }


    }

    return text;
};

function longestCommonSubstring(string1, string2){
    // init max value
    var longestCommonSubstring = 0;
    // init 2D array with 0
    var table = [],
            len1 = string1.length,
            len2 = string2.length,
            row, col;
    for(row = 0; row <= len1; row++){
        table[row] = [];
        for(col = 0; col <= len2; col++){
            table[row][col] = 0;
        }
    }
    // fill table
        var i, j;
    for(i = 0; i < len1; i++){
        for(j = 0; j < len2; j++){
            if(string1[i]==string2[j]){
                if(table[i][j] == 0){
                    table[i+1][j+1] = 1;
                } else {
                    table[i+1][j+1] = table[i][j] + 1;
                }
                if(table[i+1][j+1] > longestCommonSubstring){
                    longestCommonSubstring = table[i+1][j+1];
                }
            } else {
                table[i+1][j+1] = 0;
            }
        }
    }
    return longestCommonSubstring;
}

module.exports = PBConnect;
