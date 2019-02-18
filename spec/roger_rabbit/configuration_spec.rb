require 'spec_helper'

describe RogerRabbit::Configuration do

  describe 'Initialization' do
    let(:config) { RogerRabbit::Configuration.new }
    subject {
      config
    }

    it 'should have the correct defaults' do
      expect(subject.rabbit_mq_url).to be(nil)
      expect(subject.exchanges).to eq({})
      expect(subject.queues).to eq({})
      expect(subject.retry_exchange_name).to be(nil)
      expect(subject.dead_exchange_name).to be(nil)
    end
  end

  describe '#validate' do
    context 'Missing required option' do

      context 'exchanges' do
        it 'should raise the appropriate error' do
          expect {
            RogerRabbit.configure do |config|
              config.rabbit_mq_url = 'url'
              config.exchanges = nil
            end
          }.to raise_error(RogerRabbit::Configuration::ConfigurationError).with_message('Missing required option: exchanges')
        end
      end

      context 'queues' do
        it 'should raise the appropriate error' do
          expect {
            RogerRabbit.configure do |config|
              config.rabbit_mq_url = 'url'
              config.exchanges = {}
              config.queues = nil
            end
          }.to raise_error(RogerRabbit::Configuration::ConfigurationError).with_message('Missing required option: queues')
        end
      end
    end

    context 'exchanges option is not a hash' do

      it 'should raise the appropriate error' do
        expect {
          RogerRabbit.configure do |config|
            config.rabbit_mq_url = 'url'
            config.exchanges = []
            config.queues = {}
          end
        }.to raise_error(RogerRabbit::Configuration::ConfigurationError).with_message("exchanges must be a hash of the form 'exchange_name' => {exchange_params}")
      end
    end

    context 'queues option is not a hash' do

      it 'should raise the appropriate error' do
        expect {
          RogerRabbit.configure do |config|
            config.rabbit_mq_url = 'url'
            config.exchanges = {}
            config.queues = []
          end
        }.to raise_error(RogerRabbit::Configuration::ConfigurationError).with_message("queues must be a hash of the form 'queue_name' => {queue_params}")
      end
    end
  end
end