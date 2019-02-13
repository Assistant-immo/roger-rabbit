module RogerRabbit
  class Configuration
    attr_accessor :rabbit_mq_url, :exchanges, :queues
    
    def initialize
      @rabbit_mq_url = nil
      @exchanges = {}
      @queues = {}
    end
  end
end
