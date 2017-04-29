require 'rails_helper'

RSpec.describe Services::UploadAssignmentPeCalculations::Service, type: :service do
  subject { described_class.new }

  context 'with no AssignmentPeCalculations or AlgorithmAssignmentPeCalculations' do
    it 'does not send any AlgorithmAssignmentPeCalculations to biglearn-api' do
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

  context 'with AssignmentPeCalculations and AlgorithmAssignmentPeCalculations' do
    before(:all) do
      DatabaseCleaner.start

      algorithm_name = 'tesr'

      @a_1 = FactoryGirl.create :assignment, assignment_type: 'practice'
      @apec_1 = FactoryGirl.create :assignment_pe_calculation,
                                   assignment_uuid: @a_1.uuid,
                                   student_uuid: @a_1.student_uuid
      @aapec_1 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                    assignment_pe_calculation: @apec_1,
                                    algorithm_name: algorithm_name,
                                    is_uploaded: false

      @apec_2 = FactoryGirl.create :assignment_pe_calculation,
                                   assignment_uuid: @a_1.uuid,
                                   student_uuid: @a_1.student_uuid
      @aapec_2 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                    assignment_pe_calculation: @apec_2,
                                    algorithm_name: algorithm_name,
                                    is_uploaded: false

      @a_2 = FactoryGirl.create :assignment, assignment_type: 'practice'
      @apec_3 = FactoryGirl.create :assignment_pe_calculation,
                                   assignment_uuid: @a_2.uuid,
                                   student_uuid: @a_2.student_uuid
      @aapec_3 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                    assignment_pe_calculation: @apec_3,
                                    algorithm_name: algorithm_name,
                                    is_uploaded: true

      @apec_4 = FactoryGirl.create :assignment_pe_calculation
      @aapec_4 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                    assignment_pe_calculation: @apec_4,
                                    is_uploaded: false

      @apec_5 = FactoryGirl.create :assignment_pe_calculation
      @aapec_5 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                    assignment_pe_calculation: @apec_5,
                                    is_uploaded: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmAssignmentPeCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_pes) do |requests|
        # 2 out of 3 requests are combined together
        expect(requests.size).to eq 2

        combined_requests, single_requests = requests.partition do |request|
          request[:assignment_uuid] == @a_1.uuid
        end
        combined_request = combined_requests.first
        single_request = single_requests.first

        expected_combined_exercise_uuids = @aapec_1.exercise_uuids.first(@apec_1.exercise_count) +
                                           @aapec_2.exercise_uuids.first(@apec_2.exercise_count)
        expect(combined_request.fetch(:algorithm_name)).to eq @aapec_1.algorithm_name
        expect(combined_request.fetch(:assignment_uuid)).to eq @apec_1.assignment_uuid
        expect(combined_request.fetch(:exercise_uuids)).to(
          match_array expected_combined_exercise_uuids
        )

        expected_single_exercise_uuids = @aapec_4.exercise_uuids.first(@apec_4.exercise_count)
        expect(single_request.fetch(:algorithm_name)).to eq @aapec_4.algorithm_name
        expect(single_request.fetch(:assignment_uuid)).to eq @apec_4.assignment_uuid
        expect(single_request.fetch(:exercise_uuids)).to match_array expected_single_exercise_uuids
      end
      expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_spes)

      expect { subject.process }.to  not_change { AssignmentPeCalculation.count           }
                                .and not_change { AssignmentPeCalculationExercise.count   }
                                .and not_change { AssignmentSpeCalculation.count          }
                                .and not_change { AssignmentSpeCalculationExercise.count  }
                                .and not_change { AlgorithmAssignmentPeCalculation.count  }
                                .and not_change { AlgorithmAssignmentSpeCalculation.count }

      expect(AlgorithmAssignmentPeCalculation.where(is_uploaded: false).count).to eq 0
    end
  end
end
