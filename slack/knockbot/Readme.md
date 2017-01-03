KnockBot

# Install

Install nodejs and npm

Install module slackbots:

    npm i --save slackbots mysql

# Run

KNOCKBOT_TOKEN=xoxb-xxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx PB_USERNAME=xxxxx PB_PASSWORD=xxxxx node bin/bot.js

or 

initctl start knockbot

# Notes

You must invite a bot into a channel:
/invite @knockbot


# TODO
- stop polling the DB. find a way to push updates?
  (might not be feasible)