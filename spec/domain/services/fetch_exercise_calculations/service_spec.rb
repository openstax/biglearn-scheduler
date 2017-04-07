require 'rails_helper'

RSpec.describe Services::FetchExerciseCalculations::Service, type: :service do
  let(:service)              { described_class.new }

  let(:given_algorithm_name) { 'tesr' }

  let(:action)               { service.process(algorithm_name: given_algorithm_name) }

  context "when non-existing ExerciseCalculation algorithm_names are given" do
    it "an empty array of exercise_calculations is returned" do
      expect(action.fetch(:exercise_calculations)).to be_empty
    end
  end

  context "when previously-existing ExerciseCalculation algorithm_names are given" do
    let(:calculation_uuid_1)   { SecureRandom.uuid }
    let(:calculation_uuid_2)   { SecureRandom.uuid }
    let(:calculation_uuid_3)   { SecureRandom.uuid }

    let(:num_exercise_uuids_1) { rand(10) + 1 }
    let(:exercise_uuids_1)     { num_exercise_uuids_1.times.map { SecureRandom.uuid } }
    let(:student_uuid_1)       { SecureRandom.uuid }
    let(:ecosystem_uuid_1)     { SecureRandom.uuid }


    let(:num_exercise_uuids_2) { rand(10) + 1 }
    let(:exercise_uuids_2)     { num_exercise_uuids_2.times.map { SecureRandom.uuid } }
    let(:student_uuid_2)       { SecureRandom.uuid }
    let(:ecosystem_uuid_2)     { SecureRandom.uuid }

    let(:num_exercise_uuids_3) { rand(10) + 1 }
    let(:exercise_uuids_3)     { num_exercise_uuids_3.times.map { SecureRandom.uuid } }
    let(:student_uuid_3)       { SecureRandom.uuid }
    let(:ecosystem_uuid_3)     { SecureRandom.uuid }

    let!(:assignment_pe_calculation) do
      FactoryGirl.create :assignment_pe_calculation, uuid: calculation_uuid_1,
                                                     ecosystem_uuid: ecosystem_uuid_1,
                                                     student_uuid: student_uuid_1,
                                                     exercise_uuids: exercise_uuids_1
    end

    let!(:assignment_spe_calculation) do
      FactoryGirl.create :assignment_spe_calculation, uuid: calculation_uuid_2,
                                                      ecosystem_uuid: ecosystem_uuid_2,
                                                      student_uuid: student_uuid_2,
                                                      exercise_uuids: exercise_uuids_2
    end

    let!(:student_pe_calculation) do
      FactoryGirl.create :student_pe_calculation, uuid: calculation_uuid_3,
                                                  ecosystem_uuid: ecosystem_uuid_3,
                                                  student_uuid: student_uuid_3,
                                                  exercise_uuids: exercise_uuids_3
    end

    context "when the ExerciseCalculations have already been calculated" do
      before do
        FactoryGirl.create :algorithm_assignment_pe_calculation,
                           assignment_pe_calculation_uuid: calculation_uuid_1,
                           algorithm_name: given_algorithm_name

        FactoryGirl.create :algorithm_assignment_spe_calculation,
                           assignment_spe_calculation_uuid: calculation_uuid_2,
                           algorithm_name: given_algorithm_name

        FactoryGirl.create :algorithm_student_pe_calculation,
                           student_pe_calculation_uuid: calculation_uuid_3,
                           algorithm_name: given_algorithm_name
      end

      it "an empty array of exercise_calculations is returned" do
        expect(action.fetch(:exercise_calculations)).to be_empty
      end
    end

    context "when the ExerciseCalculations have not yet been calculated" do
      it "the exercise_calculations are returned" do
        exercise_calculations_by_uuid = {
          assignment_pe_calculation.uuid => assignment_pe_calculation,
          assignment_spe_calculation.uuid => assignment_spe_calculation,
          student_pe_calculation.uuid => student_pe_calculation
        }

        action.fetch(:exercise_calculations).each do |response|
          exercise_calculation = exercise_calculations_by_uuid.fetch(
            response.fetch(:calculation_uuid)
          )

          expect(response.fetch(:ecosystem_uuid)).to eq exercise_calculation.ecosystem_uuid
          expect(response.fetch(:student_uuid)).to eq exercise_calculation.student_uuid
          expect(response.fetch(:exercise_uuids)).to eq exercise_calculation.exercise_uuids
        end
      end
    end
  end
end