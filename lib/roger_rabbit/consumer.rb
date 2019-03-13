##
# Usage: RogerRabbit::Consumer.get_instance_for_queue('test').consume do |body|
#   success = do_something(body)
#   should return true | false
# end

module RogerRabbit
  class Consumer < Base
    DEFAULT_SUBSCRIPTION_OPTIONS = {block: true, manual_ack: true}

    def consume(subscription_options = {}, &block)
      begin
        queue_config = self.class.get_queue_config(@current_queue.name)

        @current_queue.subscribe(DEFAULT_SUBSCRIPTION_OPTIONS.merge(subscription_options)) do |_delivery_info, _properties, body|
          max_retry_count = queue_config.fetch(:max_retry_count, 0)
          headers      = _properties.headers || {}
          retry_count  = headers.fetch("x-retry-count", 0)
          correlation_id = extract_correlation_id(_properties, headers)
          reply_to = extract_reply_to(_properties, headers)

          success = block.call(body, _properties, {correlation_id: correlation_id, reply_to: reply_to}, retry_count == max_retry_count, retry_count)

          unless success
            # Taken from https://felipeelias.github.io/rabbitmq/2016/02/22/rabbitmq-exponential-backoff.html

            dead_headers = headers.fetch("x-death", []).last || {}

            expiration   = dead_headers.fetch("original-expiration", 10000).to_i

            retriable = queue_config.fetch(:retriable, false)
            exponential_backoff_factor = queue_config.fetch(:exponential_backoff_factor, 1.1)

            if retriable && retry_count < max_retry_count
              # Set the new expiration with an increasing factor
              new_expiration = expiration * exponential_backoff_factor

              # Publish to retry queue with new expiration
              self.get_retry_queue_for(@current_queue.name).publish(body, expiration: new_expiration.to_i, headers: {
                "x-retry-count": retry_count + 1,
                correlation_id: correlation_id,
                reply_to: reply_to
              })
            else
              headers = {}

              if correlation_id
                headers.merge!(correlation_id: correlation_id)
              end

              self.get_dead_queue_for(@current_queue.name).publish(body, headers)
            end
          end
          @channel.acknowledge(_delivery_info.delivery_tag, false)
        end
      rescue Interrupt => _
        self.close

        exit(0)
      end
    end

    private

      def extract_correlation_id(properties, properties_headers)
        # If retry attempt, correlation id is in the headers hash
        properties[:correlation_id] || properties_headers.fetch('correlation_id', nil)
      end

      def extract_reply_to(properties, properties_headers)
        # If retry attempt, correlation id is in the headers hash
        properties[:reply_to] || properties_headers.fetch('reply_to', nil)
      end
  end
end
