require 'rubygems'
require 'bundler'
require 'dotenv'
Dotenv.load

Bundler.require

puts File.join(Dir.pwd, 'config')

require 'octocore'
Octo.connect_with(File.join(Dir.pwd, 'config'))

require './eventsapp'
run EventsApp
