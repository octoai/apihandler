require 'sinatra/base'
require 'sinatra/config_file'
require 'securerandom'
require 'json'
require 'logger'
require 'ruby-kafka'

# Make sure to load the environment variables
#   before requiring 'octocore' gem
require 'dotenv'
Dotenv.load

require_relative 'config/version'

# APIHandler App
class EventsApp < Sinatra::Base

  ALLOWED_EVENTS = Set.new(ENV['ALLOWED_EVENTS'].split(','))

  # Set up the configuration
  configure do
    set :logging, nil
    logger = Octo::ApiLogger.logger
    set :logger, logger

    logger.info "ssss"
    kafka_config = Octo.get_config :kafka
    set kafka_bridge: Octo::KafkaBridge.new(kafka_config)
  end

  # Include the helpers
  helpers Octo::Helpers::ApiHelper

  before '/events/:event_name/'  do
    event_name = params.fetch('event_name', nil)
    if ALLOWED_EVENTS.include?event_name
      content_type :json
    else
      halt 404, {
          message: "Method [#{ event_name }] not allowed",
          event_name: event_name,
          params: params
      }.to_json
    end
  end

  # Create a product
  post '/product/' do
    instrument(:product_catalog) do
      process_request 'product.add'
    end
  end

  # modify or update product
  patch '/product' do
    instrument(:product_catalog) do
      process_request 'product.update'
    end
  end

  # delete product
  delete '/product' do
    instrument(:product_catalog) do
      process_request 'product.delete'
    end
  end

  # Handle all the /events call
  post '/events/:event_name/' do
    instrument(:event_processing) do
      process_request params['event_name']
    end
  end

  # Handle all /update_profile calls
  post '/update_profile/' do
    instrument(:update_profile) do
      process_request 'update.profile'
    end
  end

  # Handle all the /update_push_token call
  post '/update_push_token/' do
    instrument(:update_push_token) do
      process_request 'update.push_token'
    end
  end

  get '/version' do
    {
      :version => Octo::API::VERSION,
      :author => Octo::API::AUTHOR,
      :description => Octo::API::DESCRIPTION,
      :contact => Octo::API::CONTACT
    }.to_json
  end
end
