require 'rails_helper'

RSpec.describe TeacherClueCalculation, type: :model do
  subject { FactoryGirl.create :teacher_clue_calculation }

  it { is_expected.to validate_presence_of :ecosystem_uuid      }
  it { is_expected.to validate_presence_of :book_container_uuid }
  it { is_expected.to validate_presence_of :student_uuids       }
  it { is_expected.to validate_presence_of :exercise_uuids      }
  it { is_expected.to validate_presence_of :response_uuids      }
end
