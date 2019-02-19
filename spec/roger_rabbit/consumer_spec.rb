require 'spec_helper'

describe RogerRabbit::Consumer do
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

  before do
    RogerRabbit::Consumer.clear_instance
    RogerRabbit.configure do |config|
      config.rabbit_mq_url = rabbit_mq_url
      config.exchanges = exchanges
      config.queues = queues
      config.retry_exchange_name = retry_exchange_name
      config.dead_exchange_name = dead_exchange_name
      config.publisher_confirms = true
    end

    expect(Bunny).to receive(:new).with(rabbit_mq_url).and_return(connection_double)

    expect(connection_double).to receive(:start)
    expect(connection_double).to receive(:create_channel).and_return(channel_double)

    expect(channel_double).to receive(:confirm_select)
    expect(channel_double).to receive(:direct).with(retry_exchange_name, {:durable=>true}).and_return(retry_exchange_double)
    expect(channel_double).to receive(:direct).with(dead_exchange_name, {:durable=>true}).and_return(dead_exchange_double)
    expect(channel_double).to receive(:direct).with(exchange_name, {:durable=>true}).and_return(exchange_double)
    expect(channel_double).to receive(:queue).with(queue_name, {:auto_delete=>false, :durable=>true, :max_retry_count=>3}).and_return(queue_double)
    expect(channel_double).to receive(:queue).with(retry_queue_name, {:arguments=>{"x-dead-letter-exchange"=>exchange_name, "x-dead-letter-routing-key"=>queues[queue_name][:routing_key], "x-message-ttl"=>30000}, :auto_delete=>false, :durable=>true}).and_return(retry_queue_double)
    expect(channel_double).to receive(:queue).with(dead_queue_name, {:auto_delete=>false, :durable=>true}).and_return(dead_queue_double)

    expect(queue_double).to receive(:bind).with(exchange_double, {:routing_key=>queue_name})
    expect(retry_queue_double).to receive(:bind).with(retry_exchange_double, {:routing_key=>retry_queue_name})
    expect(dead_queue_double).to receive(:bind).with(dead_exchange_double, {:routing_key=>dead_queue_name})

    expect(queue_double).to receive(:subscribe).with({:block=>true, :manual_ack=>true}).and_yield(delivery_info, delivery_properties, response_body)
  end


  describe '#consume' do
    it 'should yield the block passed with the correct arguments' do
      allow(retry_queue_double).to receive(:publish)
      allow(channel_double).to receive(:acknowledge).with('delivery_tag', false)

      expect{ |probe| RogerRabbit::Consumer.get_instance_for_queue(queue_name).consume(&probe) }.to yield_with_args(response_body, delivery_properties)
    end

    context 'passed block evaluate to true' do
      let(:block) { -> (body, properties) { true } }

      it 'should not try to publish in the retry or the dead queue and acknowledge the message' do
        expect(retry_queue_double).not_to receive(:publish)
        expect(dead_queue_double).not_to receive(:publish)

        expect(channel_double).to receive(:acknowledge).with('delivery_tag', false)

        RogerRabbit::Consumer.get_instance_for_queue(queue_name).consume(&block)
      end
    end

    context 'passed block evaluate to false' do
      let(:block) { -> (body, properties) { false } }

      context 'Will retry' do
        let(:delivery_headers) { {"x-retry-count" => 0} }

        it 'should requeue the message in the retry queue' do
          expect(retry_queue_double).to receive(:publish).with(response_body, {:expiration=>11000, :headers=>{:"x-retry-count"=>1}})

          expect(channel_double).to receive(:acknowledge).with('delivery_tag', false)

          RogerRabbit::Consumer.get_instance_for_queue(queue_name).consume(&block)
        end
      end

      context 'retries exhausted' do
        let(:delivery_headers) { {"x-retry-count" => 3} }

        it 'should send the message to the dead queue' do
          expect(dead_queue_double).to receive(:publish).with(response_body)

          expect(channel_double).to receive(:acknowledge).with('delivery_tag', false)

          RogerRabbit::Consumer.get_instance_for_queue(queue_name).consume(&block)
        end
      end
    end
  end
end