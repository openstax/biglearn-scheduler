require 'rails_helper'

RSpec.describe Services::UploadStudentPeCalculations::Service, type: :service do
  subject { described_class.new }

  context 'with no StudentPeCalculations or AlgorithmStudentPeCalculations' do
    it 'does not send any AlgorithmStudentPeCalculations to biglearn-api' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_practice_worst_areas)

      expect { subject.process }.to  not_change { StudentPeCalculation.count           }
                                .and not_change { StudentPeCalculationExercise.count   }
                                .and not_change { AlgorithmStudentPeCalculation.count  }
    end
  end

  context 'with StudentPeCalculations and AlgorithmStudentPeCalculations' do
    before(:all) do
      DatabaseCleaner.start

      algorithm_map = {
        'sparfa' => 'tesr',
        'local_query' => 'local_query'
      }

      @spec_1 = FactoryGirl.create :student_pe_calculation
      @aspec_1 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    student_pe_calculation: @spec_1,
                                    algorithm_name: algorithm_map[@spec_1.clue_algorithm_name],
                                    is_uploaded: false

      @spec_2 = FactoryGirl.create :student_pe_calculation,
                                   clue_algorithm_name: @spec_1.clue_algorithm_name,
                                   student_uuid: @spec_1.student_uuid
      @aspec_2 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    student_pe_calculation: @spec_2,
                                    algorithm_name: algorithm_map[@spec_2.clue_algorithm_name],
                                    is_uploaded: false

      @spec_3 = FactoryGirl.create :student_pe_calculation
      @aspec_3 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    student_pe_calculation: @spec_3,
                                    algorithm_name: algorithm_map[@spec_3.clue_algorithm_name],
                                    is_uploaded: true

      @spec_4 = FactoryGirl.create :student_pe_calculation
      @aspec_4 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    student_pe_calculation: @spec_4,
                                    algorithm_name: algorithm_map[@spec_4.clue_algorithm_name],
                                    is_uploaded: false

      @spec_5 = FactoryGirl.create :student_pe_calculation
      @aspec_5 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    student_pe_calculation: @spec_5,
                                    algorithm_name: algorithm_map[@spec_5.clue_algorithm_name],
                                    is_uploaded: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmStudentPeCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).to receive(:update_practice_worst_areas) do |requests|
        # 2 out of 3 requests are combined together
        expect(requests.size).to eq 2

        combined_requests, single_requests = requests.partition do |request|
          request[:student_uuid] == @spec_1.student_uuid
        end
        combined_request = combined_requests.first
        single_request = single_requests.first

        expected_combined_exercise_uuids = @aspec_1.exercise_uuids.first(@spec_1.exercise_count) +
                                           @aspec_2.exercise_uuids.first(@spec_2.exercise_count)
        expect(combined_request.fetch :algorithm_name).to eq @aspec_1.algorithm_name
        expect(combined_request.fetch(:exercise_uuids)).to(
          match_array expected_combined_exercise_uuids
        )

        expected_single_exercise_uuids = @aspec_4.exercise_uuids.first(@spec_4.exercise_count)
        expect(single_request.fetch :algorithm_name).to eq @aspec_4.algorithm_name
        expect(single_request.fetch :exercise_uuids).to match_array expected_single_exercise_uuids
      end

      expect { subject.process }.to  not_change { StudentPeCalculation.count           }
                                .and not_change { StudentPeCalculationExercise.count   }
                                .and not_change { AlgorithmStudentPeCalculation.count  }

      expect(AlgorithmStudentPeCalculation.where(is_uploaded: false).count).to eq 0
    end
  end
end
