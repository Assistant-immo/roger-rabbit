require "roger_rabbit/configuration"
require "roger_rabbit/version"
require "roger_rabbit/base"
require "roger_rabbit/consumer"
require "roger_rabbit/publisher"

module RogerRabbit
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration
  end

  def self.configure
    @configuration ||= RogerRabbit::Configuration.new
    yield(configuration)
    configuration.validate
  end

  def version
    VERSION
  end
end
