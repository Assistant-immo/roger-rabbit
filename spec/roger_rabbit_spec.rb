require 'spec_helper'

describe RoggerRabbit do

  describe 'configure' do
    subject {
      RogerRabbit.configure do |config|
        config.rabbit_mq_url = rabbit_mq_url
        config.exchanges = exchanges
        config.rabbit_mq_url = queues
      end
    }

    let(:rabbit_mq_url) = 'an_url'
    let(:exchanges) = {
      'test_exchange' => {
        durable: true
      }
    }
    let(:queues) = {
        'test_queue' => {
            durable: true,
            auto_delete: false,
            exchange: 'test_exchange'
        }
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
    end
  end

end
