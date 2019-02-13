require "roger_rabbit/configuration"
require "roger_rabbit/version"
require "roger_rabbit/base_interface"
require "roger_rabbit/consumer"
require "roger_rabbit/publisher"

module RogerRabbit
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def version
    VERSION
  end
end
