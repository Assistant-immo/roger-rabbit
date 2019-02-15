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
end