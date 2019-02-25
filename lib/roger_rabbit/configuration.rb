module RogerRabbit
  class Configuration
    attr_accessor :rabbit_mq_url, :exchanges, :queues, :retry_exchange_name, :dead_exchange_name, :publisher_confirms, :consumer_prefetch_count

    ConfigurationError = Class.new(StandardError)

    REQUIRED_OPTIONS = %w{ exchanges queues }
    OPTIONAL_OPTIONS = %w{ retry_exchange_name dead_exchange_name }
    
    def initialize
      # If set to nil, rabbitMQ client will try to connect to the local rabbitMQ server running on port 5672
      @rabbit_mq_url = nil
      @exchanges = {}
      @queues = {}
      @publisher_confirms = false

      @retry_exchange_name = nil
      @dead_exchange_name = nil

      @consumer_prefetch_count = 0
    end

    def validate
      REQUIRED_OPTIONS.each do |required_option|
        option_value = self.send(required_option)

        if option_value.nil?
          raise ConfigurationError.new("Missing required option: #{required_option}")
        end
      end

      raise ConfigurationError.new("exchanges must be a hash of the form 'exchange_name' => {exchange_params}") unless self.exchanges.is_a?(Hash)
      raise ConfigurationError.new("queues must be a hash of the form 'queue_name' => {queue_params}") unless self.queues.is_a?(Hash)
    end
  end
end
