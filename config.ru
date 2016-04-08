require 'rubygems'
require 'bundler'
require 'octocore'
require 'dotenv'
Dotenv.load

Bundler.require

Octo.connect_with_config_file(File.join(Dir.pwd, 'config', 'config.yml'))

require './eventsapp'
run EventsApp
