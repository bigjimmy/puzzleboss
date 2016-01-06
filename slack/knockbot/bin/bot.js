'use strict';

var KnockBot = require('../lib/knockbot');

var token = process.env.KNOCKBOT_TOKEN;

var kb = new KnockBot({
    token: token,
    name: 'KnockBot'
});

kb.run();
