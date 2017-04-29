require 'rails_helper'

RSpec.describe Services::UploadStudentClueCalculations::Service, type: :service do
  subject { described_class.new }

  before(:all) do
    @tcc_1 = FactoryGirl.create :teacher_clue_calculation
    @atcc_1 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                 teacher_clue_calculation: @tcc_1,
                                 is_uploaded: false

    @tcc_2 = FactoryGirl.create :teacher_clue_calculation
    @atcc_2 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                 teacher_clue_calculation: @tcc_2,
                                 is_uploaded: true

    @atcc_3 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                 is_uploaded: false

    @atcc_4 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                 is_uploaded: true
  end

  context 'with no StudentClueCalculations or AlgorithmStudentClueCalculations' do
    it 'does not send any AlgorithmStudentClueCalculations to biglearn-api' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect { subject.process }.to  not_change { StudentClueCalculation.count          }
                                .and not_change { TeacherClueCalculation.count          }
                                .and not_change { AlgorithmStudentClueCalculation.count }
                                .and not_change { AlgorithmTeacherClueCalculation.count }
    end
  end

  context 'with StudentClueCalculations and AlgorithmStudentClueCalculations' do
    before(:all) do
      DatabaseCleaner.start

      @scc_1 = FactoryGirl.create :student_clue_calculation
      @ascc_1 = FactoryGirl.create :algorithm_student_clue_calculation,
                                   student_clue_calculation: @scc_1,
                                   is_uploaded: false

      @scc_2 = FactoryGirl.create :student_clue_calculation
      @ascc_2 = FactoryGirl.create :algorithm_student_clue_calculation,
                                   student_clue_calculation: @scc_2,
                                   is_uploaded: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmStudentClueCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).to receive(:update_student_clues) do |requests|
        expect(requests.size).to eq 1

        request = requests.first
        expect(request.fetch :algorithm_name).to eq @ascc_1.algorithm_name
        expect(request.fetch :book_container_uuid).to eq @scc_1.book_container_uuid
        expect(request.fetch :student_uuid).to eq @scc_1.student_uuid
        expect(request.fetch :clue_data).to eq @ascc_1.clue_data
      end
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect { subject.process }.to  not_change { StudentClueCalculation.count          }
                                .and not_change { TeacherClueCalculation.count          }
                                .and not_change { AlgorithmStudentClueCalculation.count }
                                .and not_change { AlgorithmTeacherClueCalculation.count }

      expect(AlgorithmStudentClueCalculation.where(is_uploaded: false).count).to eq 0
    end
  end
end
