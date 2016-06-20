require 'rubygems'
require 'bundler'
require 'octocore'
require 'dotenv'
Dotenv.load

Bundler.require

puts File.join(Dir.pwd, 'config')

Octo.connect_with(File.join(Dir.pwd, 'config'))

require './eventsapp'
run EventsApp
