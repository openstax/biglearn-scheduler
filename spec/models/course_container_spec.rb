require 'rails_helper'

RSpec.describe CourseContainer, type: :model do
  subject { FactoryBot.create :course_container }

  it { is_expected.to validate_presence_of :course_uuid }
end
