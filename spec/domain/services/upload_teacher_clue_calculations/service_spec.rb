require 'rails_helper'

RSpec.describe Services::UploadTeacherClueCalculations::Service, type: :service do
  subject { described_class.new }

  before(:all) do
    @scc_1 = FactoryBot.create :student_clue_calculation
    @ascc_1 = FactoryBot.create :algorithm_student_clue_calculation,
                                 student_clue_calculation: @scc_1,
                                 is_uploaded: false

    @scc_2 = FactoryBot.create :student_clue_calculation
    @ascc_2 = FactoryBot.create :algorithm_student_clue_calculation,
                                 student_clue_calculation: @scc_2,
                                 is_uploaded: true

    @ascc_3 = FactoryBot.create :algorithm_student_clue_calculation,
                                 is_uploaded: false

    @ascc_4 = FactoryBot.create :algorithm_student_clue_calculation,
                                 is_uploaded: false
  end

  context 'with no AlgorithmTeacherClueCalculations' do
    it 'does not send any AlgorithmTeacherClueCalculations to biglearn-api' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect { subject.process }.to  not_change { StudentClueCalculation.count          }
                                .and not_change { TeacherClueCalculation.count          }
                                .and not_change { AlgorithmStudentClueCalculation.count }
                                .and not_change { AlgorithmTeacherClueCalculation.count }
    end
  end

  context 'with AlgorithmTeacherClueCalculations' do
    before(:all) do
      DatabaseCleaner.start

      @tcc_1 = FactoryBot.create :teacher_clue_calculation
      @atcc_1 = FactoryBot.create :algorithm_teacher_clue_calculation,
                                   teacher_clue_calculation: @tcc_1,
                                   is_uploaded: false

      @tcc_2 = FactoryBot.create :teacher_clue_calculation
      @atcc_2 = FactoryBot.create :algorithm_teacher_clue_calculation,
                                   teacher_clue_calculation: @tcc_2,
                                   is_uploaded: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmTeacherClueCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).to receive(:update_teacher_clues) do |requests|
        expect(requests.size).to eq 1

        request = requests.first
        expect(request.fetch :algorithm_name).to eq @atcc_1.algorithm_name
        expect(request.fetch :book_container_uuid).to eq @tcc_1.book_container_uuid
        expect(request.fetch :course_container_uuid).to eq @tcc_1.course_container_uuid
        expect(request.fetch :clue_data).to eq @atcc_1.clue_data
      end

      expect { subject.process }.to  not_change { StudentClueCalculation.count          }
                                .and not_change { TeacherClueCalculation.count          }
                                .and not_change { AlgorithmStudentClueCalculation.count }
                                .and not_change { AlgorithmTeacherClueCalculation.count }

      expect(AlgorithmTeacherClueCalculation.where(is_uploaded: false).count).to eq 0
    end
  end
end
