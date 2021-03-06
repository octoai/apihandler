# API Handler #

[![Build Status](https://travis-ci.org/octoai/apihandler.svg?branch=master)](https://travis-ci.org/octoai/apihandler)

## Setup ##

- Clone the repo
- Perform git submodule update as `git submodule init`
- Install gems by `bundle install` in the working dir

## Start ##

Make sure you have all the basic steps of setup [listed here](https://github.com/octoai/octo.ai/wiki/Setup-Guide). Everything should be up and running.

- Run `bundle exec unicorn -c config/unicorn.rb --daemonize` from the PROJECT_DIR. This will start unicorn as a background process. If you want to run unicorn in foreground just drop the `--daemonize` part. The log files are located (by default) at `PROJECT_DIR/shared/log`. You should go through `config/unicorn.rb` to view/update these details.
- It accepts `POST` on `/events` and `/update_push_token` with JSON params
- It returns JSON response with the `eventId`. This `eventId` uniquely identifies the event across Octo. It can be used to trace an event.

## Stop ##

Run the following from PROJECT_DIR

```
kill -s QUIT `cat shared/pids/unicorn.pid`
```

# Setting up Initial Kong

Kong is the API Gateway we use. It exposes Octo-matic's API to the world and it's upstream is apihandler.

There is a handy utility provided in `/bin` which helps create initial kong setup.

```bash
$ bin/kong_setup.rb /path/to/config
```

It should be used for the first time for kong setup. However, it does has dependencies that should be met. For a complete details, check out the [documentation here](https://github.com/octoai/octo.ai/wiki/Setup-Guide#apihandler).

## Send some events data ##

Send events in curl as 

```
curl -X POST --header 'Content-Type: application/json' --header 'Accept: text/html' --header 'apikey: API_KEY' -d '{
  "userId": 2736482,
  "browserDetails": {
    "name": "chrome",
    "manufacturer": "Google",
    "platform": "Linux",
    "cookieid": "abc123"
  }
}' 'http://127.0.0.1:8000/events/app.init/'

# Output/Response
{"eventId":"eef1cafc-2199-428a-b12e-399bd6c7d75f"}
```
