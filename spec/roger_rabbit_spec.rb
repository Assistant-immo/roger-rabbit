require 'spec_helper'

describe RogerRabbit do

  describe 'configure' do
    let(:rabbit_mq_url) { 'an_url' }
    let(:exchanges) {
      {
        'test_exchange' => {
          durable: true
        }
      }
    }
    let(:queues) {
      {
        'test_queue' => {
          durable: true,
          auto_delete: false,
          exchange: 'test_exchange'
        }
      }
    }

    let(:retry_exchange_name) { 'retry_exchange_name' }
    let(:dead_exchange_name) { 'retry_exchange_name' }

    subject {
      RogerRabbit.configure do |config|
        config.rabbit_mq_url = rabbit_mq_url
        config.exchanges = exchanges
        config.queues = queues
        config.retry_exchange_name = retry_exchange_name
        config.dead_exchange_name = dead_exchange_name
      end
    }

    it 'configures' do
      subject
      expect(RogerRabbit.configuration.rabbit_mq_url).to eq('an_url')
      expect(RogerRabbit.configuration.exchanges).to eq({
        'test_exchange' => {
          durable: true
        }
      })
      expect(RogerRabbit.configuration.queues).to eq({
        'test_queue' => {
            durable: true,
            auto_delete: false,
            exchange: 'test_exchange'
        }
      })

      expect(RogerRabbit.configuration.retry_exchange_name).to eq(retry_exchange_name)
      expect(RogerRabbit.configuration.dead_exchange_name).to eq(dead_exchange_name)
    end
  end

end
