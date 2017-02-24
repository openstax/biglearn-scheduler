require 'rails_helper'

RSpec.describe Services::UpdateClues::Service, type: :service do
  subject { described_class.new }

  context 'with no Responses' do
    it 'does not update any CLUes' do
      expect { subject.process }.not_to change { Response.count }
    end
  end

  context 'with existing Responses and Trials' do
    before(:all) do
      DatabaseCleaner.start

      @response_1 = FactoryGirl.create :response, used_in_clues: false
      @response_2 = FactoryGirl.create :response, used_in_clues: false
      @response_3 = FactoryGirl.create :response, used_in_clues: false

      @trial_1 = FactoryGirl.create :trial, uuid: @response_1.uuid
      @trial_2 = FactoryGirl.create :trial, uuid: @response_2.uuid
      @trial_3 = FactoryGirl.create :trial, uuid: @response_3.uuid
    end

    after(:all)  { DatabaseCleaner.clean }

    it 'marks the Response objects as processed' do
      expect do
        subject.process
      end.to  not_change { Response.count }
         .and change     { @response_1.reload.used_in_clues }.from(false).to(true)
         .and change     { @response_2.reload.used_in_clues }.from(false).to(true)
         .and change     { @response_3.reload.used_in_clues }.from(false).to(true)
    end
  end
end
