require 'spec_helper'

describe RogerRabbit::BaseInterface do

  describe 'instance' do
    subject {
      RogerRabbit::BaseInterface.instance
    }

    it 'should return a properly configured instance' do
      expect_any_instance_of(RogerRabbit::BaseInterface).to receive(:init_connection_and_channel)

      instance = subject

      expect(instance).to have_attributes(class: RogerRabbit::BaseInterface, exchanges: {}, queues: {})
    end

    it 'should be a singleton' do
      instance = subject
      instance2 = subject

      expect(instance).to equal(instance2)
    end
  end

  describe 'get_instance_for_queue' do
    let(:queue_name) { 'queue_test' }

    subject {
      RogerRabbit::BaseInterface.get_instance_for_queue(queue_name)
    }

    context 'The connection is either new or currently opened' do
      let(:exchange_name) { 'exchange_name' }
      let(:exchange_config) { {exchange_config: true} }
      let(:queue_config) { {queue_config: true} }
      let(:instance) { double('Instance') }

      it 'should call the right methods' do
        expect(RogerRabbit::BaseInterface).to receive(:get_exchange_for_queue).with(queue_name).and_return(exchange_name)
        expect(RogerRabbit::BaseInterface).to receive(:get_exchange_config).with(exchange_name).and_return(exchange_config)
        expect(RogerRabbit::BaseInterface).to receive(:get_queue_config).with(queue_name).and_return(queue_config)
        expect(RogerRabbit::BaseInterface).to receive(:instance).and_return(instance)

        expect(instance).to receive(:connection_closed)

        expect(instance).to receive(:set_retriable_exchanges)
        expect(instance).to receive(:set_exchange).with(exchange_config.dup.merge(name: exchange_name))
        expect(instance).to receive(:set_queue).with(queue_config.dup.merge(name: queue_name))

        expect(subject).to eq(instance)
      end
    end
  end

  describe '#close' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:connection) { double('Connection') }
    subject {
      instance.close
    }

    it 'should call the right methods' do
      instance.instance_variable_set(:@connection, connection)
      instance.instance_variable_set(:@channel, 'not_nil')
      instance.instance_variable_set(:@exchanges, { filled: true } )
      instance.instance_variable_set(:@queues, { filled: true })

      expect(connection).to receive(:close).and_return('result')

      expect(subject).to eq('result')

      expect(instance.connection).to be(nil)
      expect(instance.channel).to be(nil)
      expect(instance.exchanges).to eq({})
      expect(instance.queues).to eq({})
      expect(instance.connection_closed).to be(true)
    end
  end

  describe '#initialize' do
    let(:instance) { RogerRabbit::BaseInterface.instance }

    subject {
      instance.send(:initialize)
    }

    it 'should call the correct methods' do
      expect(instance).to receive(:init_connection_and_channel)

      subject

      expect(instance.exchanges).to eq({})
      expect(instance.queues).to eq({})
    end
  end

  describe 'new' do
    subject {
      RogerRabbit::BaseInterface.new
    }

    it 'should be a private method' do
      expect {
        subject
      }.to raise_error(NoMethodError).with_message("private method `new' called for RogerRabbit::BaseInterface:Class")
    end
  end

  describe '#init_connection_and_channel' do
    let(:instance) { RogerRabbit::BaseInterface.instance }

    subject {
      instance.send(:init_connection_and_channel)
    }

    it 'should call the correct methods' do
      expect(RogerRabbit.configuration).to receive(:rabbit_mq_url).and_return('rabbit_mq_url')

      expect(instance).to receive(:open_rabbit_mq_connection).with('rabbit_mq_url')
      expect(instance).to receive(:create_channel).and_return('create_channel_response')

      expect(subject).to eq('create_channel_response')

      expect(instance.connection_closed).to be(false)
    end
  end

  describe '#open_rabbit_mq_connection' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:url) { 'url' }
    let(:connection_double) { double('Connection') }

    subject {
      instance.send(:open_rabbit_mq_connection, url)
    }

    it 'should call the correct methods' do
      expect(Bunny).to receive(:new).with(url).and_return(connection_double)
      expect(connection_double).to receive(:start)

      subject

      expect(instance.connection).to eq(connection_double)
    end
  end

  describe '#create_channel' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:connection_double) { double('Connection') }
    let(:channel_double) { double('Channel') }

    subject {
      instance.send(:create_channel)
    }

    before do
      instance.instance_variable_set(:@connection, connection_double)
    end

    it 'should call the correct methods' do
      expect(connection_double).to receive(:create_channel).and_return(channel_double)
      expect(channel_double).to receive(:confirm_select)

      subject
    end
  end

  describe '#set_retriable_exchanges' do
    let(:instance) { RogerRabbit::BaseInterface.instance }

    subject {
      instance.send(:set_retriable_exchanges)
    }

    it 'should call the correct methods' do
      expect(instance).to receive(:set_retry_exchange)
      expect(instance).to receive(:set_dead_exchange)

      subject
    end
  end

  describe '#set_retry_exchange' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:retry_exchange_name) { 'retry_exchange_name' }
    let(:channel_double) { double('Channel') }

    subject {
      instance.send(:set_retry_exchange)
    }

    before do
      instance.instance_variable_set(:@channel, channel_double)
    end

    it 'should call the correct methods' do
      expect(RogerRabbit.configuration).to receive(:retry_exchange_name).exactly(:twice).and_return(retry_exchange_name)
      expect(channel_double).to receive(:direct).with(retry_exchange_name, {durable: true}).and_return('retry_exchange_instance')

      subject

      expect(instance.exchanges).to eq({retry_exchange_name =>"retry_exchange_instance"})
    end
  end

  describe '#get_retry_queue_name' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:queue_name) { 'queue_name' }
    subject {
      instance.send(:get_retry_queue_name, queue_name)
    }

    it 'should return the correct queue name' do
      expect(subject).to eq("retry_#{queue_name}")
    end
  end

  describe 'set_retry_queue' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:queue_name) { 'queue_name' }
    let(:channel_double) { double('Channel') }
    let(:queue_double) { double('Queue') }

    subject {
      instance.send(:set_retry_queue, queue_name)
    }

    before do
      instance.instance_variable_set(:@channel, channel_double)
      instance.instance_variable_set(:@exchanges, {'retry_exchange_name' => 'retry_exchange_instance'})
    end

    context 'Retry queue not set' do
      it 'should set the retry queue' do
        expect(RogerRabbit.configuration).to receive(:retry_exchange_name).and_return('retry_exchange_name')

        expect(instance).to receive(:get_retry_queue_name).with(queue_name).and_return('retry_queue_name')
        expect(instance.class).to receive(:get_exchange_for_queue).with(queue_name).and_return('queue_exchange_name')

        expect(channel_double).to receive(:queue).with('retry_queue_name', {
          durable: true,
          auto_delete: false,
          arguments: {
            'x-dead-letter-exchange' => 'queue_exchange_name',
            'x-dead-letter-routing-key' => queue_name,
            # Default TTL set to 5 minutes, will likely be overriden by exponential backoff if set
            'x-message-ttl' => 30000
          }
        }).and_return(queue_double)

        expect(queue_double).to receive(:bind).with('retry_exchange_instance', routing_key: 'retry_queue_name')

        subject

        expect(instance.queues['retry_queue_name']).to eq(queue_double)
      end
    end

    context 'Retry queue set' do
      before do
        instance.instance_variable_set(:@queues, {'retry_queue_name' => 'retry_queue_instance'})
      end

      it 'should not create a new queue and reuse the existing one' do
        expect(instance).to receive(:get_retry_queue_name).with(queue_name).and_return('retry_queue_name')
        expect(channel_double).not_to receive(:queue)

        subject

        expect(instance.queues).to eq({'retry_queue_name' => 'retry_queue_instance'})
      end
    end
  end

  describe '#get_retry_queue_for' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:queue_name) { 'queue_name' }

    subject {
      instance.send(:get_retry_queue_for, queue_name)
    }

    before do
      instance.instance_variable_set(:@queues, {'retry_queue_name' => 'retry_queue_instance'})
    end

    it 'should return the correct result' do
      expect(instance).to receive(:get_retry_queue_name).with(queue_name.to_sym).and_return('retry_queue_name')

      expect(subject).to eq('retry_queue_instance')
    end
  end

  describe '#set_dead_exchange' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:dead_exchange_name) { 'dead_exchange_name' }
    let(:channel_double) { double('Channel') }

    subject {
      instance.send(:set_dead_exchange)
    }

    before do
      instance.instance_variable_set(:@exchanges, {})
      instance.instance_variable_set(:@channel, channel_double)
    end

    it 'should call the correct methods' do
      expect(RogerRabbit.configuration).to receive(:dead_exchange_name).exactly(:twice).and_return(dead_exchange_name)
      expect(channel_double).to receive(:direct).with(dead_exchange_name, {durable: true}).and_return('dead_exchange_instance')

      subject

      expect(instance.exchanges).to eq({dead_exchange_name =>"dead_exchange_instance"})
    end
  end

  describe '#get_dead_queue_name' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:queue_name) { 'queue_name' }
    subject {
      instance.send(:get_dead_queue_name, queue_name)
    }

    it 'should return the correct queue name' do
      expect(subject).to eq("dead_#{queue_name}")
    end
  end

  describe 'set_dead_queue' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:queue_name) { 'queue_name' }
    let(:channel_double) { double('Channel') }
    let(:queue_double) { double('Queue') }

    subject {
      instance.send(:set_dead_queue, queue_name)
    }

    before do
      instance.instance_variable_set(:@channel, channel_double)
      instance.instance_variable_set(:@exchanges, {'dead_exchange_name' => 'dead_exchange_instance'})
    end

    context 'Retry queue not set' do
      it 'should set the retry queue' do
        expect(RogerRabbit.configuration).to receive(:dead_exchange_name).and_return('dead_exchange_name')

        expect(instance).to receive(:get_dead_queue_name).with(queue_name).and_return('dead_queue_name')

        expect(channel_double).to receive(:queue).with('dead_queue_name', {
          durable: true,
          auto_delete: false
        }).and_return(queue_double)

        expect(queue_double).to receive(:bind).with('dead_exchange_instance', routing_key: 'dead_queue_name')

        subject

        expect(instance.queues['dead_queue_name']).to eq(queue_double)
      end
    end

    context 'Dead queue set' do
      before do
        instance.instance_variable_set(:@queues, {'dead_queue_name' => 'dead_queue_instance'})
      end

      it 'should not create a new queue and reuse the existing one' do
        expect(instance).to receive(:get_dead_queue_name).with(queue_name).and_return('dead_queue_name')
        expect(channel_double).not_to receive(:queue)

        subject

        expect(instance.queues).to eq({'dead_queue_name' => 'dead_queue_instance'})
      end
    end
  end

  describe '#get_dead_queue_for' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:queue_name) { 'queue_name' }

    subject {
      instance.send(:get_dead_queue_for, queue_name)
    }

    before do
      instance.instance_variable_set(:@queues, {'dead_queue_name' => 'dead_queue_instance'})
    end

    it 'should return the correct result' do
      expect(instance).to receive(:get_dead_queue_name).with(queue_name.to_sym).and_return('dead_queue_name')

      expect(subject).to eq('dead_queue_instance')
    end
  end

  describe '#set_exchange' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:params) {
      {
        name: 'exchange_name',
        param1: 1,
        param2: 2
      }
    }
    let(:channel_double) { double('Channel') }

    subject {
      instance.send(:set_exchange, params)
    }

    before do
      instance.instance_variable_set(:@channel, channel_double)
      instance.instance_variable_set(:@exchanges, {})
    end

    context 'Exchange not already set' do
      it 'should update exchanges variable and the current_exchange variable' do
        expect(channel_double).to receive(:direct).with('exchange_name', {param1: 1, param2: 2}).and_return('exchange_instance')

        subject

        expect(instance.exchanges).to eq({'exchange_name' => 'exchange_instance'})
        expect(instance.current_exchange).to eq('exchange_instance')
      end
    end

    context 'Exchange already set' do
      before do
        instance.instance_variable_set(:@exchanges, {'exchange_name' => 'exchange_instance'})
      end

      it 'should not create a new exchange and use the existing one' do
        expect(channel_double).not_to receive(:direct)

        subject

        expect(instance.exchanges).to eq({'exchange_name' => 'exchange_instance'})
        expect(instance.current_exchange).to eq('exchange_instance')
      end
    end
  end

  describe '#set_queue' do
    let(:instance) { RogerRabbit::BaseInterface.instance }
    let(:params) {
      {
        name: 'queue_name',
        routing_key: 'routing_key',
        exchange: 'exchange',
        retriable: retriable,
        param1: 1,
        param2: 2
      }
    }
    let(:queue_double) { double('Queue') }
    let(:channel_double) { double('Channel') }
    let(:exchange_double) { double('Exchange') }

    subject {
      instance.send(:set_queue, params)
    }

    before do
      instance.instance_variable_set(:@queues, {})
      instance.instance_variable_set(:@channel, channel_double)
      instance.instance_variable_set(:@exchanges, {'exchange' => exchange_double})
    end

    context 'retriable set to false' do
      let(:retriable) { false }

      it 'should call the right methods' do
        expect(channel_double).to receive(:queue).with('queue_name', {param1: 1, param2: 2}).and_return(queue_double)

        expect(queue_double).to receive(:bind).with(exchange_double, routing_key: 'routing_key')
        expect(instance).not_to receive(:set_retry_queue)
        expect(instance).not_to receive(:set_dead_queue)

        subject

        expect(instance.queues).to eq({'queue_name' => queue_double})
        expect(instance.current_queue).to eq(queue_double)
      end
    end

    context 'retriable set to true' do
      let(:retriable) { true }

      it 'should call the right methods' do
        expect(channel_double).to receive(:queue).with('queue_name', {param1: 1, param2: 2}).and_return(queue_double)
        expect(queue_double).to receive(:bind).with(exchange_double, routing_key: 'routing_key')
        expect(instance).to receive(:set_retry_queue).with('queue_name')
        expect(instance).to receive(:set_dead_queue).with('queue_name')

        subject

        expect(instance.queues).to eq({'queue_name' => queue_double})
        expect(instance.current_queue).to eq(queue_double)
      end
    end

    context 'queue is already set' do
      let(:retriable) { false }

      before do
        instance.instance_variable_set(:@queues, { 'queue_name' => queue_double })
      end

      it 'should call the right methods' do
        expect(channel_double).not_to receive(:queue)
        expect(queue_double).not_to receive(:bind)

        subject

        expect(instance.current_queue).to eq(queue_double)
      end
    end
  end

  describe 'get_exchange_for_queue' do
    let(:queue_name) { 'queue_name' }

    subject {
      RogerRabbit::BaseInterface.send(:get_exchange_for_queue, queue_name)
    }

    context 'No exchange linked to the queue' do

      before do
        expect(RogerRabbit::BaseInterface).to receive(:get_queue_config).with(queue_name).and_return({})
      end

      it 'should raise an error' do
        expect {
          subject
        }.to raise_error(RogerRabbit::BaseInterface::ConfigurationError).with_message('No mapped exchange to queue <queue_name>')
      end
    end

    context 'An exchange is linked to the queue' do
      before do
        expect(RogerRabbit::BaseInterface).to receive(:get_queue_config).with(queue_name).and_return({exchange: 'exchange_name'})
      end

      it 'should return the exchange name' do
        expect(subject).to eq('exchange_name')
      end
    end
  end

  describe 'get_exchange_config' do
    let(:exchange_name) { 'exchange_name' }

    subject {
      RogerRabbit::BaseInterface.send(:get_exchange_config, exchange_name)
    }

    context 'No exchange config' do

      before do
        expect(RogerRabbit.configuration).to receive(:exchanges).and_return({})
      end

      it 'should raise an error' do
        expect {
          subject
        }.to raise_error(RogerRabbit::BaseInterface::ConfigurationError).with_message('No configuration for exchange <exchange_name>')
      end
    end

    context 'A config for the exchange exists' do
      before do
        expect(RogerRabbit.configuration).to receive(:exchanges).and_return({exchange_name => {config: 1}})
      end

      it 'should return the exchange name' do
        expect(subject).to eq({config: 1})
      end
    end
  end

  describe 'get_queue_config' do
    let(:queue_name) { 'queue_name' }

    subject {
      RogerRabbit::BaseInterface.send(:get_queue_config, queue_name)
    }

    context 'No queue config' do

      before do
        expect(RogerRabbit.configuration).to receive(:queues).and_return({})
      end

      it 'should raise an error' do
        expect {
          subject
        }.to raise_error(RogerRabbit::BaseInterface::ConfigurationError).with_message('No configuration for queue <queue_name>')
      end
    end

    context 'A config for the queue exists' do
      before do
        expect(RogerRabbit.configuration).to receive(:queues).and_return({queue_name => {config: 1}})
      end

      it 'should return the exchange name' do
        expect(subject).to eq({config: 1})
      end
    end
  end
end