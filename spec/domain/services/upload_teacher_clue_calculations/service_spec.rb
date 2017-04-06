require 'rails_helper'

RSpec.describe Services::UploadTeacherClueCalculations::Service, type: :service do
  subject { described_class.new }

  before(:all) do
    @scc_1 = FactoryGirl.create :student_clue_calculation
    @ascc_1 = FactoryGirl.create :algorithm_student_clue_calculation,
                                 student_clue_calculation_uuid: @scc_1.uuid,
                                 sent_to_api_server: false

    @scc_2 = FactoryGirl.create :student_clue_calculation
    @ascc_2 = FactoryGirl.create :algorithm_student_clue_calculation,
                                 student_clue_calculation_uuid: @scc_2.uuid,
                                 sent_to_api_server: true

    @ascc_3 = FactoryGirl.create :algorithm_student_clue_calculation,
                                 sent_to_api_server: false

    @ascc_4 = FactoryGirl.create :algorithm_student_clue_calculation,
                                 sent_to_api_server: false
  end

  context 'with no AlgorithmTeacherClueCalculations' do
    it 'does not send any AlgorithmTeacherClueCalculations to biglearn-api' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect { subject.process }.to  not_change { Response.count                        }
                                .and not_change { ResponseClue.count                    }
                                .and not_change { StudentClueCalculation.count          }
                                .and not_change { TeacherClueCalculation.count          }
                                .and not_change { AlgorithmStudentClueCalculation.count }
                                .and not_change { AlgorithmTeacherClueCalculation.count }
    end
  end

  context 'with AlgorithmTeacherClueCalculations' do
    before(:all) do
      DatabaseCleaner.start

      @tcc_1 = FactoryGirl.create :teacher_clue_calculation
      @atcc_1 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                   teacher_clue_calculation_uuid: @tcc_1.uuid,
                                   sent_to_api_server: false

      @tcc_2 = FactoryGirl.create :teacher_clue_calculation
      @atcc_2 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                   teacher_clue_calculation_uuid: @tcc_2.uuid,
                                   sent_to_api_server: true

      @atcc_3 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                   sent_to_api_server: false

      @atcc_4 = FactoryGirl.create :algorithm_teacher_clue_calculation,
                                   sent_to_api_server: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it "sends the AlgorithmTeacherClueCalculations that haven't been sent yet to biglearn-api" do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).to receive(:update_teacher_clues) do |requests|
        expect(requests.size).to eq 1

        request = requests.first
        expect(request.fetch :book_container_uuid).to eq @tcc_1.book_container_uuid
        expect(request.fetch :course_container_uuid).to eq @tcc_1.course_container_uuid
        expect(request.fetch :algorithm_name).to eq @atcc_1.algorithm_name
        expect(request.fetch :clue_data).to eq @atcc_1.clue_data
      end

      expect { subject.process }.to  not_change { Response.count                        }
                                .and not_change { ResponseClue.count                    }
                                .and not_change { StudentClueCalculation.count          }
                                .and not_change { TeacherClueCalculation.count          }
                                .and not_change { AlgorithmStudentClueCalculation.count }
                                .and not_change { AlgorithmTeacherClueCalculation.count }
    end
  end
end
