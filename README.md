# API Handler #

[![Build Status](https://travis-ci.org/octoai/apihandler.svg?branch=master)](https://travis-ci.org/octoai/apihandler)

## Setup ##

- Clone the repo
- Perform git submodule update as `git submodule init`
- Install gems by `bundle install` in the working dir

## Start ##

Make sure you have all the basic steps of setup [listed here](https://github.com/octoai/octo.ai/wiki/Setup-Guide). Everything should be up and running.

- Run `./start.sh` from the PROJECT_DIR
- It accepts `POST` on `/events` and `/update_push_token` with JSON params
- It returns JSON response with the `eventId`. This `eventId` uniquely identifies the event across Octo. It can be used to trace an event.

## Stop ##

Run the following from PROJECT_DIR

```
kill -s QUIT `cat shared/pids/unicorn.pid`
```

## Send some events data ##

Send events in curl as 

```
curl \
--data '{"event_name":"page.view","event_param":"12"}' \
http://127.0.0.1:9001/events

# Output/Response
{"eventId":"eef1cafc-2199-428a-b12e-399bd6c7d75f"}
```

# Setting up Initial Kong

There is a handy utility provided in `/bin` which helps create initial kong setup.

It should be used for the first time for kong setup. However, it does has dependencies that should be met. For a complete details, check out the [documentation here](https://github.com/octoai/octo.ai/wiki/Setup-Guide#apihandler).
