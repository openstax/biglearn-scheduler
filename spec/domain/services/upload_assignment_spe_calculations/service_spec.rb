require 'rails_helper'

RSpec.describe Services::UploadAssignmentSpeCalculations::Service, type: :service do
  subject { described_class.new }

  context 'with no AssignmentSpeCalculations or AlgorithmAssignmentSpeCalculations' do
    it 'does not send any AlgorithmAssignmentSpeCalculations to biglearn-api' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_pes)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_spes)

      expect { subject.process }.to  not_change { AssignmentPeCalculation.count           }
                                .and not_change { AssignmentPeCalculationExercise.count   }
                                .and not_change { AssignmentSpeCalculation.count          }
                                .and not_change { AssignmentSpeCalculationExercise.count  }
                                .and not_change { AlgorithmAssignmentPeCalculation.count  }
                                .and not_change { AlgorithmAssignmentSpeCalculation.count }
    end
  end

  context 'with AssignmentSpeCalculations and AlgorithmAssignmentSpeCalculations' do
    before(:all) do
      DatabaseCleaner.start

      algorithm_name = 'tesr'

      @a_1 = FactoryGirl.create :assignment, assignment_type: 'practice'
      @aspec_1 = FactoryGirl.create :assignment_spe_calculation,
                                    assignment_uuid: @a_1.uuid,
                                    student_uuid: @a_1.student_uuid,
                                    history_type: 'student_driven'
      @aaspec_1 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation: @aspec_1,
                                     algorithm_name: algorithm_name,
                                     is_uploaded: false

      @aspec_2 = FactoryGirl.create :assignment_spe_calculation,
                                    assignment_uuid: @a_1.uuid,
                                    student_uuid: @a_1.student_uuid,
                                    history_type: 'student_driven'
      @aaspec_2 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation: @aspec_2,
                                     algorithm_name: algorithm_name,
                                     is_uploaded: false

      @a_2 = FactoryGirl.create :assignment, assignment_type: 'practice'
      @aspec_3 = FactoryGirl.create :assignment_spe_calculation,
                                    assignment_uuid: @a_2.uuid,
                                    student_uuid: @a_2.student_uuid,
                                    history_type: 'student_driven'
      @aaspec_3 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation: @aspec_3,
                                     algorithm_name: algorithm_name,
                                     is_uploaded: false

      @aspec_4 = FactoryGirl.create :assignment_spe_calculation,
                                    assignment_uuid: @a_2.uuid,
                                    student_uuid: @a_2.student_uuid,
                                    history_type: 'instructor_driven'
      @aaspec_4 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation: @aspec_4,
                                     algorithm_name: algorithm_name,
                                     is_uploaded: false

      @aspec_5 = FactoryGirl.create :assignment_spe_calculation
      @aaspec_5 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation: @aspec_5,
                                     is_uploaded: true

      @aspec_6 = FactoryGirl.create :assignment_spe_calculation
      @aaspec_6 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation: @aspec_6,
                                     is_uploaded: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmAssignmentSpeCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_spes) do |requests|
        # 2 out of 4 requests are combined together
        expect(requests.size).to eq 3

        combined_requests, single_requests = requests.partition do |request|
          request[:assignment_uuid] == @a_1.uuid
        end
        combined_request = combined_requests.first
        student_single_requests, instructor_single_requests = single_requests.partition do |request|
          request[:algorithm_name].include? 'student_driven'
        end
        student_single_request = student_single_requests.first
        instructor_single_request = instructor_single_requests.first

        expected_combined_exercise_uuids = @aaspec_1.exercise_uuids.first(@aspec_1.exercise_count) +
                                           @aaspec_2.exercise_uuids.first(@aspec_2.exercise_count)
        expect(combined_request.fetch(:algorithm_name)).to(
          eq [@aaspec_1.algorithm_name, @aspec_1.history_type].join('_')
        )
        expect(combined_request.fetch(:assignment_uuid)).to eq @aspec_1.assignment_uuid
        expect(combined_request.fetch(:exercise_uuids)).to(
          match_array expected_combined_exercise_uuids
        )

        expected_student_single_exercise_uuids =
          @aaspec_3.exercise_uuids.first(@aspec_3.exercise_count)
        expect(student_single_request.fetch(:algorithm_name)).to(
          eq [@aaspec_3.algorithm_name, @aspec_3.history_type].join('_')
        )
        expect(student_single_request.fetch(:assignment_uuid)).to eq @a_2.uuid
        expect(student_single_request.fetch(:exercise_uuids)).to(
          match_array expected_student_single_exercise_uuids
        )

        expected_instructor_single_exercise_uuids =
          @aaspec_4.exercise_uuids.first(@aspec_4.exercise_count)
        expect(instructor_single_request.fetch(:algorithm_name)).to(
          eq [@aaspec_4.algorithm_name, @aspec_4.history_type].join('_')
        )
        expect(instructor_single_request.fetch(:assignment_uuid)).to eq @a_2.uuid
        expect(instructor_single_request.fetch(:exercise_uuids)).to(
          match_array expected_instructor_single_exercise_uuids
        )
      end
      expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_pes)

      expect { subject.process }.to  not_change { AssignmentPeCalculation.count           }
                                .and not_change { AssignmentPeCalculationExercise.count   }
                                .and not_change { AssignmentSpeCalculation.count          }
                                .and not_change { AssignmentSpeCalculationExercise.count  }
                                .and not_change { AlgorithmAssignmentPeCalculation.count  }
                                .and not_change { AlgorithmAssignmentSpeCalculation.count }

      expect(AlgorithmAssignmentSpeCalculation.where(is_uploaded: false).count).to eq 0
    end
  end
end
