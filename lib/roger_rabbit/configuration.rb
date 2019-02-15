module RogerRabbit
  class Configuration
    attr_accessor :rabbit_mq_url, :exchanges, :queues, :retry_exchange_name, :dead_exchange_name
    
    def initialize
      @rabbit_mq_url = nil
      @exchanges = {}
      @queues = {}

      @retry_exchange_name = nil
      @dead_exchange_name = nil
    end
  end
end
