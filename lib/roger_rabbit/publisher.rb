##
# Usage: RogerRabbit::Publisher.get_instance_for_queue('test').publish(100.times.map{|| {ok: true}.to_json})

module RogerRabbit
  class Publisher < BaseInterface

    def publish(messages, &block)
      publish_to_queue(messages)
      # Publisher confirm
      success = @channel.wait_for_confirms

      if success
        if block_given?
          block.call
        end
      end

      success
    end

    private

    def publish_to_queue(messages)
      routing_key = BaseInterface.get_queue_config(@current_queue.name)[:routing_key]
      [messages].flatten.each do |message|
        @current_exchange.publish(message, routing_key: routing_key, content_type: "application/json", persistent: true)
      end
    end
  end
end
