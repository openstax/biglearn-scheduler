require 'rails_helper'

RSpec.describe ResponseClue, type: :model do
  subject { FactoryGirl.create :response_clue }

  it { is_expected.to validate_presence_of :course_uuid }
end
