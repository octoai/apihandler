#!/usr/bin/env ruby
#
#
# This executable file is responsible for creating kong configuration
# from a provided config file.
#
# refer to the provided kong_config.yaml

require 'yaml'
require 'curb'
require 'octocore'
require 'securerandom'
require 'digest/sha1'

module Octo

  module EnterpriseGenetaor

    def create_enterprise(enterprise)
      Octo.logger.info "Attempting to create new enterprise with name: #{ enterprise[:name]}"
      redis_config = {
        host: Octo.get_config(:redis).fetch(:host, '127.0.0.1'), 
        port: Octo.get_config(:redis).fetch(:port, 6379)
      }
      # Establish connection to redis server
      @redis = Redis.new(redis_config)

      unless enterprise_name_exists?(enterprise[:name])

        # create enterprise
        e = Octo::Enterprise.new
        e.name = enterprise[:name]
        e.save!

        enterprise_id = e.id.to_s

        # create its Authentication stuff
        auth = Octo::Authorization.new
        auth.enterprise_id = enterprise_id
        auth.username = e.name
        auth.email = enterprise[:email]
        auth.custom_id = enterprise_id
        auth.password = enterprise[:password]
        auth.admin = enterprise[:admin]
        auth.save!

        # Create key authorizaton
        apikey = Octo::ApiKey.new
        apikey.enterprise_key = auth.apikey
        apikey.enterprise_id = auth.enterprise_id
        apikey.save!

        @redis.set(apikey.enterprise_key, apikey.enterprise_id)
      else
        Octo.logger.warn 'Not creating client as client name exists'
      end
    end

    def enterprise_name_exists?(enterprise_name)
      @enterprise_names ||= Octo::Enterprise.all
      @enterprise_names.select { |x| x.name == enterprise_name}.length > 0
    end

  end


  class EnterpriseCreator

    extend Octo::EnterpriseGenetaor

    class << self

      def create(config)
        @config = config

        # create consumers
        @config[:clients].each do |enterprise|
          create_enterprise(enterprise)
        end
      end
    end

  end
end

def help
  puts <<HELP
Usage:
./initialize_octo.rb path/to/config

  /path/to/config would be the path where you cloned config repo

** Unable to find appropriate config dir path.
HELP
end

if __FILE__ == $0

  if ARGV.length != 1
    help
  else
    STDOUT.sync = true
    expected_dir_path = ARGV[0]
    Octo.connect_with expected_dir_path
    Octo::EnterpriseCreator.create Octo.get_config(:init_config)
  end

end

