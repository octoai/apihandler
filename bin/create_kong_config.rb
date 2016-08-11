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
require 'json'
require 'securerandom'
require 'digest/sha1'

module Octo

  module EnterpriseGenetaor

    def create_enterprise(enterprise)
      Octo.logger.info "Attempting to create new enterprise with name: #{ enterprise[:name]}"
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

        method = :put
        url = '/consumers/'
        payload = {username: e.name, custom_id: e.id.to_s}
        make_kong_request method, url, payload

        create_key_auth_config(e.name, auth.apikey)
      else
        Octo.logger.warn 'Not creating client as client name exists'
      end
    end


    def create_api(api)
      url = '/apis'
      method = :put
      payload = {
          strip_request_path: true,
          preserve_host: false
      }
      payload.merge!api
      make_kong_request method, url, payload
    end

    def create_plugin(api_name, plugin, config = {})
      Octo.logger.info "Adding Plugin #{ plugin } for api #{ api_name }"
      method = :put
      url = "/apis/#{ api_name}/plugins"
      payload = {
          name: plugin
      }
      _config = config.deep_dup
      _config.keys.each do |k|
        _config['config.' + k.to_s] = _config.delete(k)
      end
      payload.merge!_config
      make_kong_request method, url, payload
    end

    def create_plugin_for_client(api_name, plugin, consumer_id, config = {})
      Octo.logger.info "Adding Plugin #{ plugin } for api #{ api_name } for consumer: #{ consumer_id }"
      method = :put
      url = "/apis/#{ api_name}/plugins"
      payload = { name: plugin, consumer_id: consumer_id }
      _config = config.deep_dup
      _config.keys.each do |k|
        _config['config.' + k.to_s] = _config.delete(k)
      end
      payload.merge!_config
      make_kong_request method, url, payload
    end

    private

    def create_key_auth_config(consumer_name, key)
      method = :post
      url = "/consumers/#{consumer_name}/key-auth"
      payload = {
          key: key
      }
      make_kong_request method, url, payload
    end

    # Gets the current consumers listed in Kong.
    def current_consumers
      make_kong_request :get, '/consumers/' do |r|
        @current_consumers = r
      end
      @current_consumers
    end

    def current_api_names
      apis = make_kong_request :get, '/apis'
      apis['data'].collect { |x| x['name'] } rescue []
    end

    def enterprise_name_exists?(enterprise_name)
      @enterprise_names ||= Octo::Enterprise.all
      @enterprise_names.select { |x| x.name == enterprise_name}.length > 0
    end

    def make_kong_request(method, url, payload = {}, &block)
      args = [@config[:kong] + url]
      if [:post, :put].include?method
        args << payload.to_json
        req = Curl.public_send(method, *args ) do |http|
          http.headers['Accept'] = 'application/json, text/plain, */*'
          http.headers['Content-Type'] = 'application/json;charset=UTF-8'
          http.on_success do |data|
            begin
              res = JSON.parse data.body_str
              if block_given?
                yield res
              else
                Octo.logger.info res
              end
            rescue Exception => e
              Octo.logger.error "Error in yield block: #{ e }"
            end
          end
          http.on_failure do |data|
            Octo.logger.error "Kong Request Failed: #{ data.status }, #{ data.body }"
          end
        end
      elsif method == :get
        req = Curl.public_send(method, *args ) do |http|
          http.headers['Accept'] = 'application/json, text/plain, */*'
          http.on_success do |data|
            begin
              res = JSON.parse data.body_str
              if block_given?
                yield res
              else
                Octo.logger.info res
              end
            rescue Exception => e
              Octo.logger.error "Error in yield Block: #{ e }"
            end
          end
          http.on_failure do |data|
            Octo.logger.error "Kong Request Failed: #{ data.status }, #{ data.body }"
          end
        end
      end
    end

  end


  class EnterpriseCreator

    extend Octo::EnterpriseGenetaor

    class << self

      def create(config)
        @config = config

        # create APIs
        expected_api_names = @config[:apis].collect { |x| x[:name]}
        apis_to_create = expected_api_names - current_api_names

        apis_to_create.each do |api|
          api_config = @config[:apis].select { |x| x[:name] == api}.first
          create_api(api_config)
        end

        # create consumers
        @config[:clients].each do |enterprise|
          create_enterprise(enterprise)
        end

        consumer_info = current_consumers['data']

        # create Plugins
        @config[:plugins].each do |plugin_name, plugin_conf|
          apis = plugin_conf[:apis]
          clients = plugin_conf[:clients]
          config = plugin_conf[:config]
          apis.each do |api|
            if clients == 'all'
              create_plugin api, plugin_name, config
            else
              clients.each do |client|
                client_config = @config[:clients].select { |x| x[:name].to_s.downcase == client.to_s.downcase }.first
                client_plugin_config = client_config[plugin_name]
                consumer = consumer_info.select { |x| x['username'].to_s.downcase == client.to_s.downcase }.first
                create_plugin_for_client api, plugin_name, consumer['id'], client_plugin_config
              end
            end
          end
        end
      end
    end

  end
end

def help
  puts <<HELP
Usage:
./create_kong_config.rb path/to/config

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
    Octo::EnterpriseCreator.create Octo.get_config(:kong_config)
  end

end

