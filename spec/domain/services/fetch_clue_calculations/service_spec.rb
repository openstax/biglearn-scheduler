require 'rails_helper'

RSpec.describe Services::FetchClueCalculations::Service, type: :service do
  let(:service)              { described_class.new }

  let(:given_algorithm_name) { 'sparfa' }

  let(:action)               { service.process(algorithm_name: given_algorithm_name) }

  context "when non-existing ClueCalculation algorithm_names are given" do
    it "an empty array of clue_calculations is returned" do
      expect(action.fetch(:clue_calculations)).to be_empty
    end
  end

  context "when previously-existing ClueCalculation algorithm_names are given" do
    let(:calculation_uuid_1)   { SecureRandom.uuid }
    let(:calculation_uuid_2)   { SecureRandom.uuid }

    let(:num_exercise_uuids_1) { rand(10) + 1 }
    let(:exercise_uuids_1)     { num_exercise_uuids_1.times.map { SecureRandom.uuid } }
    let(:student_uuid_1)       { SecureRandom.uuid }
    let(:ecosystem_uuid_1)     { SecureRandom.uuid }


    let(:num_exercise_uuids_2) { rand(10) + 1 }
    let(:num_student_uuids_2)  { rand(10) + 1 }
    let(:exercise_uuids_2)     { num_exercise_uuids_2.times.map { SecureRandom.uuid } }
    let(:student_uuids_2)      { num_student_uuids_2.times.map  { SecureRandom.uuid } }
    let(:ecosystem_uuid_2)     { SecureRandom.uuid }

    let!(:student_clue_calculation) do
      FactoryGirl.create :student_clue_calculation, uuid: calculation_uuid_1,
                                                    ecosystem_uuid: ecosystem_uuid_1,
                                                    exercise_uuids: exercise_uuids_1,
                                                    student_uuid: student_uuid_1
    end

    let!(:teacher_clue_calculation) do
      FactoryGirl.create :teacher_clue_calculation, uuid: calculation_uuid_2,
                                                    ecosystem_uuid: ecosystem_uuid_2,
                                                    exercise_uuids: exercise_uuids_2,
                                                    student_uuids: student_uuids_2
    end

    context "when the ClueCalculations have already been calculated" do
      before do
        FactoryGirl.create :algorithm_student_clue_calculation,
                           student_clue_calculation_uuid: calculation_uuid_1,
                           algorithm_name: given_algorithm_name

        FactoryGirl.create :algorithm_teacher_clue_calculation,
                           teacher_clue_calculation_uuid: calculation_uuid_2,
                           algorithm_name: given_algorithm_name
      end

      it "an empty array of clue_calculations is returned" do
        expect(action.fetch(:clue_calculations)).to be_empty
      end
    end

    context "when the ClueCalculations have not yet been calculated" do
      it "the clue_calculations are returned" do
        clue_calculations_by_uuid = {
          student_clue_calculation.uuid => student_clue_calculation,
          teacher_clue_calculation.uuid => teacher_clue_calculation
        }

        action.fetch(:clue_calculations).each do |response|
          clue_calculation = clue_calculations_by_uuid.fetch response.fetch(:calculation_uuid)

          expect(response.fetch(:ecosystem_uuid)).to eq clue_calculation.ecosystem_uuid
          expect(response.fetch(:exercise_uuids)).to eq clue_calculation.exercise_uuids
          expect(response.fetch(:student_uuids)).to eq clue_calculation.student_uuids
        end
      end
    end
  end
end
