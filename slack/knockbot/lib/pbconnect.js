'use strict';

/* TODO:
 * - do something when the database connection drops!
 */

var refresh_rate = 20*1000; // Refresh from database every 30 seconds

var mysql = require('mysql');

var PBConnect = function Constructor() {
    this.con = null;

    this.connection_options = {
        host: "localhost",
        port: "3306",
        user: process.env.PB_USERNAME,
        password: process.env.PB_PASSWORD
    };

    this.puzzle_counts = {new_count: 0, solved_count: 0, eyes_count: 0, total_count: 0};
    this.round_count = 0;
};

PBConnect.prototype.connect = function() {
    // First you need to create a connection to the db
    this.con = mysql.createConnection(this.connection_options);
    this.connect_helper();
};

PBConnect.prototype.connect_helper = function() {
    // Connect to the DB
    this.con.connect(function (err) {
        if (err) {
            console.log('Error connecting to Db');
            return;
        }
        //console.log('Connection established');
    });
};

PBConnect.prototype.disconnect = function() {
    this.con.end(function(err) {
        // The connection is terminated gracefully
        // Ensures all previously enqueued queries are still
        // before sending a COM_QUIT packet to the MySQL server.
    });
};

PBConnect.prototype.test_query = function(query) {
    this.con.query(query,function(err,rows){
        if(err) throw err;

        console.log(query);
        console.log('Data received from Db:');
        console.log(rows);
        console.log('\n');
    });
};

// Connect to the database
function refresh_status(self) {
    self.con.query('SELECT * FROM puzzlebitch.puzzle', function (err, rows) {
        if (err) {
            return;
        }

        var new_count = 0;
        var solved_count = 0;
        var eyes_count = 0;
        var total_count = rows.length;

        for (var r = 0; r < rows.length; r++) {
            switch (rows[r].status) {
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

        self.puzzle_counts = {new_count: new_count, solved_count: solved_count, eyes_count: eyes_count, total_count: total_count};

    });

    self.con.query('SELECT * FROM puzzlebitch.round', function (err, rows) {
        if (err) {
            return;
        }
        self.round_count = rows.length;
    });
};

// Set an interval to refresh from the database at the given rate
PBConnect.prototype.continual_refresh = function() {
    var self = this;
    refresh_status(self);
    setInterval(refresh_status, refresh_rate, self);
};

// Return a string about the puzzle status
PBConnect.prototype.string_puzzle_status = function() {
    var text = '';

    // Don't say anything if there's no puzzles
    if (this.puzzle_counts.total_count == 0 && this.puzzle_counts.round_count == 0)
        return 'No puzzles yet!';

    // How many new puzzles?
    var new_count_plural = (this.puzzle_counts.new_count == 1) ? '' : 's';
    if (this.puzzle_counts.new_count > 0) {
        text += this.puzzle_counts.new_count + ' new puzzle' + new_count_plural + '\n';
    }
    
    // How many need eyes?
    var eye_count_plural = (this.puzzle_counts.eyes_count == 1) ? '' : 's';
    if (this.puzzle_counts.eyes_count > 0) {
        text += this.puzzle_counts.eyes_count + ' puzzle needs eyes' + eye_count_plural + '\n';
    }

    // Puzzle counts
    var total_count_plural = (this.puzzle_counts.total_count == 1) ? '' : 's';
    var round_count_plural = (this.round_count == 1) ? '' : 's';

    text += 'Solved ' + this.puzzle_counts.solved_count + ' of '
         + this.puzzle_counts.total_count + ' puzzle' + total_count_plural + ' across '
         + this.round_count + ' round' + round_count_plural;

    return text;
};

module.exports = PBConnect;
