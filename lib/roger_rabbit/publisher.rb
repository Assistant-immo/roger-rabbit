##
# Usage: RogerRabbit::Publisher.get_instance_for_queue('test').publish(100.times.map{|| {ok: true}.to_json})

module RogerRabbit
  class Publisher < Base

    PublisherError = Class.new(StandardError)
    PayloadMissingError = Class.new(PublisherError)

    def publish(messages, publish_params = {}, &block)
      publish_to_queue(messages, publish_params)
      # Publisher confirm
      success = if RogerRabbit.configuration.publisher_confirms
                  @channel.wait_for_confirms
                else
                  true
                end

      if success
        if block_given?
          block.call
        end
      end

      success
    end

    private

    def publish_to_queue(messages, publish_params)
      routing_key = Publisher.get_queue_config(@current_queue.name)[:routing_key]
      params = {routing_key: routing_key, content_type: "application/json", persistent: true}.merge(publish_params)

      [messages].flatten.each do |message|
        publishing_message_params = params.merge(extract_publishing_params(message))

        message_payload = extract_message_payload(message)

        @current_exchange.publish(message_payload, publishing_message_params)
      end
    end

    def extract_publishing_params(message)
      if message.is_a?(Hash) && message[:publishing_params]
        message[:publishing_params]
      elsif message.respond_to?(:publishing_params)
        message.publishing_params
      else
        {}
      end
    end

    def extract_message_payload(message)
      if message.is_a?(Hash)
        payload = message[:payload]
        raise PayloadMissingError.new("#{message.inspect} must have a ':payload' key defining its payload") if payload.nil?
        payload
      elsif message.respond_to?(:payload)
        payload = message.payload
        raise PayloadMissingError.new("The 'payload' method of #{message.inspect} must return a non-nil payload") if payload.nil?
        payload
      else
        message
      end
    end
  end
end
