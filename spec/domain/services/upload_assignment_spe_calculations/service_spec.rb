require 'rails_helper'

RSpec.describe Services::UploadAssignmentSpeCalculations::Service, type: :service do
  subject { described_class.new }

  before(:all) do
    @apec_1 = FactoryGirl.create :assignment_pe_calculation
    @aapec_1 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                  assignment_pe_calculation_uuid: @apec_1.uuid,
                                  is_uploaded: false

    @apec_2 = FactoryGirl.create :assignment_pe_calculation
    @aapec_2 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                  assignment_pe_calculation_uuid: @apec_2.uuid,
                                  is_uploaded: true

    @aapec_3 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                  is_uploaded: false

    @aapec_4 = FactoryGirl.create :algorithm_assignment_pe_calculation,
                                  is_uploaded: true
  end

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

      @aspec_1 = FactoryGirl.create :assignment_spe_calculation
      @aaspec_1 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation_uuid: @aspec_1.uuid,
                                     is_uploaded: false

      @aspec_2 = FactoryGirl.create :assignment_spe_calculation
      @aaspec_2 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     assignment_spe_calculation_uuid: @aspec_2.uuid,
                                     is_uploaded: true

      @aaspec_3 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     is_uploaded: false

      @aaspec_4 = FactoryGirl.create :algorithm_assignment_spe_calculation,
                                     is_uploaded: false
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmAssignmentSpeCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_pes)
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_spes) do |requests|
        expect(requests.size).to eq 1

        request = requests.first
        expect(request.fetch :algorithm_name).to eq @aaspec_1.algorithm_name
        expect(request.fetch :assignment_uuid).to eq @aspec_1.assignment_uuid
        expect(request.fetch :exercise_uuids).to eq @aaspec_1.exercise_uuids
      end

      expect { subject.process }.to  not_change { AssignmentPeCalculation.count           }
                                .and not_change { AssignmentPeCalculationExercise.count   }
                                .and not_change { AssignmentSpeCalculation.count          }
                                .and not_change { AssignmentSpeCalculationExercise.count  }
                                .and not_change { AlgorithmAssignmentPeCalculation.count  }
                                .and not_change { AlgorithmAssignmentSpeCalculation.count }

      AlgorithmAssignmentSpeCalculation.all.each do |algorithm_assignment_spe_calculation|
        expect(algorithm_assignment_spe_calculation.is_uploaded).to eq true
      end
    end
  end
end
