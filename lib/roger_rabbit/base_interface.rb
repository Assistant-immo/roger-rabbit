require 'bunny'

module RogerRabbit
  class BaseInterface

    class InterfaceError < StandardError; end
    class ConfigurationError < InterfaceError; end

    RETRY_MESSAGES_EXCHANGE_NAME = 'retry_messages_exchange'
    DEAD_MESSAGES_EXCHANGE_NAME = 'dead_messages_exchange'

    attr_reader :connection, :channel, :exchanges, :queues, :current_queue,
      :current_exchange, :connection_params, :connection_closed

    @@singleton__instance__ = nil
    @@singleton__mutex__ = Mutex.new
    def self.instance url
      return @@singleton__instance__ if @@singleton__instance__
      @@singleton__mutex__.synchronize {
        return @@singleton__instance__ if @@singleton__instance__
        @@singleton__instance__ = new(url)
      }
      @@singleton__instance__
    end

    def self.get_instance_for_queue(queue_name)
      exchange_name = self.get_exchange_for_queue(queue_name)
      if exchange_name == nil || exchange_name == ''
        raise ConfigurationError.new("No mapped exchange to queue <#{queue_name}>")
      end

      exchange_config = self.get_exchange_config(exchange_name)
      if exchange_config == nil || exchange_config == {}
        raise ConfigurationError.new("No configuration for exchange <#{exchange_name}>")
      end

      queue_config = self.get_queue_config(queue_name)
      if queue_config == nil || queue_config == {}
        raise ConfigurationError.new("No configuration for queue <#{queue_name}>")
      end


      instance = self.instance(RogerRabbit.configuration.rabbit_mq_url)

      if instance.connection_closed
        instance.send(:init_connection_and_channel)
      end

      instance.send(:set_retriable_exchanges)
      # We dup the config objects because we later one modify it by deleting keys
      instance.send(:set_exchange, exchange_config.dup.merge(name: exchange_name))
      instance.send(:set_queue, queue_config.dup.merge(name: queue_name))

      instance
    end

    # Should be called to close the rabbitMQ connection
    def close
      close_connection_result = @connection.close
      @connection = nil
      @channel = nil

      # Exchanges and queues linked to now closed channel will not work anymore
      @exchanges = {}
      @queues = {}

      @connection_closed = true

      close_connection_result
    end

    protected

    def initialize(url)
      @exchanges = {}
      @queues = {}

      init_connection_and_channel url
    end

    private_class_method :new

    def init_connection_and_channel url
      open_rabbit_mq_connection(url)
      channel_creation_result = create_channel

      @connection_closed = false

      channel_creation_result
    end

    def open_rabbit_mq_connection(url)
      @connection = Bunny.new(url)
      @connection.start
    end

    def create_channel
      @channel = @connection.create_channel
      @channel.confirm_select
    end

    def set_retriable_exchanges
      set_retry_exchange
      set_dead_exchange
    end

    def set_retry_exchange
      @exchanges[RETRY_MESSAGES_EXCHANGE_NAME] ||= @channel.direct(RETRY_MESSAGES_EXCHANGE_NAME, {durable: true})
    end

    def get_retry_queue_name(queue_name)
      "retry_#{queue_name}"
    end

    def set_retry_queue(for_queue)
      retry_queue_name = get_retry_queue_name(for_queue)
      if @queues[retry_queue_name] == nil
        @queues[retry_queue_name] = @channel.queue(retry_queue_name, {
            durable: true,
            auto_delete: false,
            arguments: {
                'x-dead-letter-exchange' => self.class.get_exchange_for_queue(for_queue),
                'x-dead-letter-routing-key' => for_queue,
                # Default TTL set to 5 minutes, will likely be overriden by exponential backoff if set
                'x-message-ttl' => 30000
            }
        })
        @queues[retry_queue_name].bind(@exchanges[RETRY_MESSAGES_EXCHANGE_NAME], routing_key: retry_queue_name)
      end
    end

    def get_retry_queue_for(queue_name)
      @queues[get_retry_queue_name(queue_name.to_sym)]
    end

    def set_dead_exchange
      @exchanges[DEAD_MESSAGES_EXCHANGE_NAME] ||= @channel.direct(DEAD_MESSAGES_EXCHANGE_NAME, {durable: true})
    end

    def get_dead_queue_name(queue_name)
      "dead_#{queue_name}"
    end

    def set_dead_queue(for_queue)
      dead_queue_name = get_dead_queue_name(for_queue)
      if @queues[dead_queue_name] == nil
        @queues[dead_queue_name] = @channel.queue(dead_queue_name, {
            durable: true,
            auto_delete: false
        })
        @queues[dead_queue_name].bind(@exchanges[:dead_messages_exchange], routing_key: dead_queue_name)
      end
    end

    def get_dead_queue_for(queue_name)
      @queues[get_dead_queue_name(queue_name.to_sym)]
    end

    def set_exchange(exchange_params)
      exchange_name = exchange_params.delete(:name)

      @exchanges[exchange_name] ||= @channel.direct(exchange_name, exchange_params)
      @current_exchange = @exchanges[exchange_name]
    end

    def set_queue(queue_params)
      queue_name = queue_params.delete(:name)
      routing_key = queue_params.delete(:routing_key)
      exchange = queue_params.delete(:exchange)
      retriable = queue_params.delete(:retriable)

      # Create a durable queue (meaning the messages ar epersisted to disk, thus allowing resilience against broker shutdown)
      # We set the queue to auto_delete false so that it is not deleted when no consumers are subscribed to it
      if @queues[queue_name] == nil
        @queues[queue_name] = @channel.queue(queue_name, queue_params)
        @queues[queue_name].bind(@exchanges[exchange], routing_key: routing_key)
      end

      if retriable
        set_retry_queue(queue_name)
        set_dead_queue(queue_name)
      end

      @current_queue = @queues[queue_name]
    end

    def self.get_exchange_for_queue(queue_name)
      self.get_queue_config(queue_name)[:exchange]
    end

    def self.get_exchange_config(exchange_name)
      RogerRabbit.configuration.exchanges[exchange_name]
    end

    def self.get_queue_config(queue_name)
      RogerRabbit.configuration.queues[queue_name]
    end
  end
end
