require 'spec_helper'

describe RogerRabbit::Publisher do
  let(:queue_name) { 'queue_name' }
  let(:dead_queue_name) { 'dead_queue_name' }
  let(:retry_queue_name) { 'retry_queue_name' }
  let(:exchange_name) { 'test_exchange' }
  let(:rabbit_mq_url) { 'rabbit_mq_url' }
  let(:exchanges) {
    {
      exchange_name => {
        durable: true
      }
    }
  }
  let(:queues) {
    {
      queue_name => {
        durable: true,
        auto_delete: false,
        retriable: true,
        max_retry_count: 3,
        routing_key: queue_name,
        exchange: exchange_name
      }
    }
  }
  let(:retry_exchange_name) { 'retry_exchange_name' }
  let(:dead_exchange_name) { 'dead_exchange_name' }

  let(:connection_double) { double('Consumer Connection') }
  let(:channel_double) { double('Consumer Channel') }
  let(:queue_double) { double('Consumer Queue', name: queue_name) }
  let(:dead_queue_double) { double('Consumer Dead Queue', name: dead_queue_name)}
  let(:retry_queue_double) { double('Consumer Retry Queue', name: dead_queue_name)}
  let(:retry_exchange_double) { double('Retry Exchange Instance')}
  let(:dead_exchange_double) { double('Dead Exchange Instance')}
  let(:exchange_double) { double('Exchange Instance')}

  let(:response_body) { 'response_body' }
  let(:delivery_info) { double('Delivery Infos', delivery_tag: 'delivery_tag') }
  let(:delivery_properties) { double('Delivery Properties', headers: delivery_headers) }

  let(:delivery_headers) { {} }

  let(:publisher_confirms) { true }

  before do
    RogerRabbit::Consumer.clear_instance
    RogerRabbit.configure do |config|
      config.rabbit_mq_url = rabbit_mq_url
      config.exchanges = exchanges
      config.queues = queues
      config.retry_exchange_name = retry_exchange_name
      config.dead_exchange_name = dead_exchange_name
      config.publisher_confirms = publisher_confirms
      config.consumer_prefetch_count = 10
    end

    expect(Bunny).to receive(:new).with(rabbit_mq_url).and_return(connection_double)

    expect(connection_double).to receive(:start)
    expect(connection_double).to receive(:create_channel).and_return(channel_double)

    if publisher_confirms
      expect(channel_double).to receive(:confirm_select)
    else
      expect(channel_double).not_to receive(:confirm_select)
    end

    expect(channel_double).to receive(:prefetch).with(10)
    expect(channel_double).to receive(:direct).with(retry_exchange_name, {:durable=>true}).and_return(retry_exchange_double)
    expect(channel_double).to receive(:direct).with(dead_exchange_name, {:durable=>true}).and_return(dead_exchange_double)
    expect(channel_double).to receive(:direct).with(exchange_name, {:durable=>true}).and_return(exchange_double)
    expect(channel_double).to receive(:queue).with(queue_name, {:auto_delete=>false, :durable=>true, :max_retry_count=>3}).and_return(queue_double)
    expect(channel_double).to receive(:queue).with(retry_queue_name, {:arguments=>{"x-dead-letter-exchange"=>exchange_name, "x-dead-letter-routing-key"=>queues[queue_name][:routing_key], "x-message-ttl"=>30000}, :auto_delete=>false, :durable=>true}).and_return(retry_queue_double)
    expect(channel_double).to receive(:queue).with(dead_queue_name, {:auto_delete=>false, :durable=>true}).and_return(dead_queue_double)

    expect(queue_double).to receive(:bind).with(exchange_double, {:routing_key=>queue_name})
    expect(retry_queue_double).to receive(:bind).with(retry_exchange_double, {:routing_key=>retry_queue_name})
    expect(dead_queue_double).to receive(:bind).with(dead_exchange_double, {:routing_key=>dead_queue_name})
  end

  describe '#publish' do
    let(:messages) { ['message1', 'message2'] }

    context 'No block given' do

      context 'Success' do
        let(:success) { true }

        it 'should call the right methods' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect(instance).to receive(:publish_to_queue).with(messages, {})
          expect(channel_double).to receive(:wait_for_confirms).and_return(success)
          expect(instance.publish(messages)).to be(success)
        end
      end

      context 'Failure' do
        let(:success) { false }

        it 'should call the right methods' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect(instance).to receive(:publish_to_queue).with(messages, {})
          expect(channel_double).to receive(:wait_for_confirms).and_return(success)
          expect(instance.publish(messages)).to be(success)
        end
      end
    end

    context 'Block given' do

      context 'Success' do
        let(:success) { true }

        it 'should call the right methods and call the block' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect(instance).to receive(:publish_to_queue).with(messages, {})
          expect(channel_double).to receive(:wait_for_confirms).and_return(success)
          expect{ |probe| instance.publish(messages, &probe) }.to yield_with_no_args
        end
      end

      context 'Failure' do
        let(:success) { false }

        it 'should call the right methods and not call the block' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect(instance).to receive(:publish_to_queue).with(messages, {})
          expect(channel_double).to receive(:wait_for_confirms).and_return(success)
          expect{ |probe| instance.publish(messages, &probe) }.not_to yield_control
        end
      end
    end

    context 'channel is not in publisher confirms mode' do
      let(:publisher_confirms) { false }

      it 'should call the right methods' do
        instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

        expect(instance).to receive(:publish_to_queue).with(messages, {})
        expect(channel_double).not_to receive(:wait_for_confirms)

        expect(instance.publish(messages)).to eq(true)
      end
    end
  end

  describe '#publish_to_queue' do
    let(:messages) { [1,2,3] }

    it 'should call the right methods' do
      instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

      expect(exchange_double).to receive(:publish).with(1, {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key]})
      expect(exchange_double).to receive(:publish).with(2, {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key]})
      expect(exchange_double).to receive(:publish).with(3, {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key]})

      instance.send(:publish_to_queue, messages, {})
    end

    context 'some publishing params are passed' do
      let(:publishing_params) { {extra_param: 1} }

      it 'should merge the publishing params with the standard params' do
        instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

        expect(exchange_double).to receive(:publish).with(1, {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key], :extra_param=>1})
        expect(exchange_double).to receive(:publish).with(2, {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key], :extra_param=>1})
        expect(exchange_double).to receive(:publish).with(3, {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key], :extra_param=>1})

        instance.send(:publish_to_queue, messages, publishing_params)
      end
    end

    context 'messages are hashes' do

      context 'payload and publishing_params present' do
        let(:messages) { [{payload: 'payload', publishing_params: {param1: 1, param2: 2}}] }

        it 'should merge the publishing params with the standard params and use the correct payload' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect(exchange_double).to receive(:publish).with('payload', {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key], :param1=>1, :param2=>2})

          instance.send(:publish_to_queue, messages, {})
        end
      end

      context 'No payload on the message' do
        let(:messages) { [{publishing_params: {param1: 1, param2: 2}}] }

        it 'should raise an error' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect {
            instance.send(:publish_to_queue, messages, {})
          }.to raise_error(RogerRabbit::Publisher::PayloadMissingError).with_message("{:publishing_params=>{:param1=>1, :param2=>2}} must have a ':payload' key defining its payload")
        end
      end
    end

    context 'messages are objects responding to the payload method' do

      context 'payload and publishing_params available' do
        let(:messages) { [OpenStruct.new(payload: 'payload', publishing_params: {param1: 1})] }

        it 'should merge the publishing params with the standard params and use the correct payload' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect(exchange_double).to receive(:publish).with('payload', {:content_type=>"application/json", :persistent=>true, :routing_key=>queues[queue_name][:routing_key], :param1=>1})

          instance.send(:publish_to_queue, messages, {})
        end
      end

      context 'no payload returned' do
        let(:messages) { [OpenStruct.new(payload: nil, publishing_params: {param1: 1})] }

        it 'should raise an error' do
          instance = RogerRabbit::Publisher.get_instance_for_queue(queue_name)

          expect {
            instance.send(:publish_to_queue, messages, {})
          }.to raise_error(RogerRabbit::Publisher::PayloadMissingError).with_message("The 'payload' method of #<OpenStruct payload=nil, publishing_params={:param1=>1}> must return a non-nil payload")
        end
      end
    end
  end
end