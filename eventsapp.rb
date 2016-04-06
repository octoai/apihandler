require 'sinatra/base'
require 'sinatra/config_file'
require 'securerandom'
require 'json'
require 'ruby-kafka'
require_relative 'config/version'
require 'dotenv'

Dotenv.load

# The bridge between Kafka and ruby
class KafkaBridge

  # These are hard wired
  CLIENT_ID = 'eventsWebApp'
  TOPIC     = 'events'

  # Changes as per environment
  BROKERS   = ENV['KAFKA_BROKERS'].split(',')

  @@kafka = Kafka.new(
    seed_brokers: BROKERS,
    client_id: CLIENT_ID)


  @@msgCount = 0

  @@producer = @@kafka.get_producer

  # Creates a new message.
  # @param [Hash] message The message hash to be produced
  def self.createMessage(message)
    # the topic at which we send is 'events'
    @@producer.produce(message, topic: TOPIC)
    @@msgCount += 1
    self.sendMessages
  end

  # Sends all the messages produced by the producer
  # till now
  def self.sendMessages
    @@producer.send_messages
  end

end

# Pushes to kafka
# @param [Hash] params The request params
# @param [String] uuid The UUID associated with
#   these params
def pushToKafka(params, uuid, enterprise)
  params['uuid'] = uuid
  params['enterprise'] = enterprise
  KafkaBridge.createMessage(JSON.generate(params))
  KafkaBridge.sendMessages
end

# Generate a UUID for each response
# @return [String] UUID
def genResponseToken()
  return SecureRandom.uuid
end

# Events app
class EventsApp < Sinatra::Base

  ALLOWED_EVENTS = %w( app.init app.login app.logout
  page.view productpage.view )

  configure do
    enable :logging
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
  end

  post '/events/:event_name/' do
    content_type :json

    event_name = params['event_name']

    if ALLOWED_EVENTS.include?(event_name)
      postParams = JSON.parse(request.env["rack.input"].read)
      postParams[:event_name] = event_name
      enterpriseId,
        enterpriseCustomId,
        enterpriseUsername = %w(HTTP_X_CONSUMER_ID HTTP_X_CONSUMER_CUSTOM_ID HTTP_X_CONSUMER_USERNAME).collect do |prop|
         request.env.fetch(prop, nil)
      end
      logger.info "#{ enterpriseId }, #{ enterpriseCustomId }, #{ enterpriseUsername }"
      uuid = genResponseToken()
      enterprise = {
        id: enterpriseId,
        customId: enterpriseCustomId,
        userName: enterpriseUsername
      }
      pushToKafka(postParams, uuid, enterprise)
      return { :eventId => uuid }.to_json
    else
      status 404
      return { :code => 420,
               :message => 'Method not allowed',
               :fields => event_name
             }.to_json
    end
  end

  post '/update_push_token/' do
    content_type :json

    postParams = JSON.parse(request.env["rack.input"].read)
    postParams[:event_name] = 'update.push_token'
    enterpriseId,
      enterpriseCustomId,
      enterpriseUsername = %w(HTTP_X_CONSUMER_ID HTTP_X_CONSUMER_CUSTOM_ID HTTP_X_CONSUMER_USERNAME).collect do |prop|
       request.env.fetch(prop, nil)
    end
    enterprise = {
      id: enterpriseId,
      customId: enterpriseCustomId,
      userName: enterpriseUsername
    }
    uuid = genResponseToken()
    pushToKafka(postParams, uuid, enterprise)
    return { :eventId => uuid }.to_json
  end

  get '/version' do

    return {
        :version => Octo::VERSION,
        :author => Octo::AUTHOR,
        :description => Octo::DESCRIPTION,
        :contact => Octo::CONTACT
      }.to_json
  end

end
