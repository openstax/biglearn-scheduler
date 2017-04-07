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
                                    student_pe_calculation_uuid: @spec_1.uuid,
                                    algorithm_name: algorithm_map[@spec_1.clue_algorithm_name],
                                    is_uploaded: false

      @spec_2 = FactoryGirl.create :student_pe_calculation
      @aspec_2 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    student_pe_calculation_uuid: @spec_2.uuid,
                                    algorithm_name: algorithm_map[@spec_2.clue_algorithm_name],
                                    is_uploaded: true

      @aspec_3 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    is_uploaded: false

      @aspec_4 = FactoryGirl.create :algorithm_student_pe_calculation,
                                    is_uploaded: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmStudentPeCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).to receive(:update_practice_worst_areas) do |requests|
        expect(requests.size).to eq 1

        request = requests.first
        expect(request.fetch :algorithm_name).to eq @aspec_1.algorithm_name
        expect(request.fetch :student_uuid).to   eq @spec_1.student_uuid
        expect(request.fetch :exercise_uuids).to eq @aspec_1.exercise_uuids
      end

      expect { subject.process }.to  not_change { StudentPeCalculation.count           }
                                .and not_change { StudentPeCalculationExercise.count   }
                                .and not_change { AlgorithmStudentPeCalculation.count  }

      AlgorithmStudentPeCalculation.all.each do |algorithm_student_pe_calculation|
        expect(algorithm_student_pe_calculation.is_uploaded).to eq true
      end
    end
  end
end
