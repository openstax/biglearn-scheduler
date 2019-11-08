require 'rails_helper'

RSpec.describe Services::UpdateExerciseCalculations::Service, type: :service do
  let(:service)                       { described_class.new }

  let(:given_algorithm_name)          { 'biglearn_sparfa' }

  let(:given_calculation_uuid_1)      { SecureRandom.uuid }
  let(:given_ecosystem_matrix_uuid_1) { SecureRandom.uuid }
  let(:num_exercise_uuids_1)          { rand(10) }
  let(:given_exercise_uuids_1)        { num_exercise_uuids_1.times.map { SecureRandom.uuid } }

  let(:given_calculation_uuid_2)      { SecureRandom.uuid }
  let(:given_ecosystem_matrix_uuid_2) { SecureRandom.uuid }
  let(:num_exercise_uuids_2)          { rand(10) }
  let(:given_exercise_uuids_2)        { num_exercise_uuids_2.times.map { SecureRandom.uuid } }

  let(:algorithm_exercise_calculation_attributes_set) do
    Set[
      [
        given_algorithm_name,
        given_calculation_uuid_1,
        given_ecosystem_matrix_uuid_1,
        given_exercise_uuids_1
      ],
      [
        given_algorithm_name,
        given_calculation_uuid_2,
        given_ecosystem_matrix_uuid_2,
        given_exercise_uuids_2
      ]
    ]
  end

  let(:given_exercise_calculation_updates) do
    algorithm_exercise_calculation_attributes_set
      .map do |algorithm_name, calculation_uuid, ecosystem_matrix_uuid, exercise_uuids|
      {
        calculation_uuid: calculation_uuid,
        algorithm_name: algorithm_name,
        ecosystem_matrix_uuid: ecosystem_matrix_uuid,
        exercise_uuids: exercise_uuids
      }
    end
  end

  let(:action)  do
    service.process(exercise_calculation_updates: given_exercise_calculation_updates)
  end
  let(:results) { action.fetch(:exercise_calculation_update_responses) }

  context 'when non-existing ExerciseCalculation uuids are given' do
    it 'does not create new records and returns calculation_status: "calculation_unknown"' do
      expect { action }.not_to change { AlgorithmExerciseCalculation.count }

      results.each { |result| expect(result[:calculation_status]).to eq 'calculation_unknown' }
    end
  end

  context 'when previously-existing ExerciseCalculation uuids are given' do
    let!(:exercise_calculation_1) do
      FactoryBot.create :exercise_calculation, uuid: given_calculation_uuid_1
    end
    let!(:exercise_calculation_2) do
      FactoryBot.create :exercise_calculation, uuid: given_calculation_uuid_2
    end

    context 'when non-existing AlgorithmExerciseCalculation' +
            ' algorithm_name and calculation_uuids are given' do
      it 'creates new records and returns calculation_status: "calculation_accepted"' do
        expect { action }.to  change     { AlgorithmExerciseCalculation.count }.by(2)
                         .and not_change { AssignmentPe.count  }
                         .and not_change { AssignmentSpe.count }
                         .and not_change { StudentPe.count     }

        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }

        algorithm_exercise_calculation_attributes = AlgorithmExerciseCalculation.pluck(
          :algorithm_name, :exercise_calculation_uuid, :ecosystem_matrix_uuid, :exercise_uuids
        )
        algorithm_exercise_calculation_attributes.each do |attributes|
          expect(algorithm_exercise_calculation_attributes_set).to include attributes
        end
      end
    end

    context 'when previously-existing AlgorithmExerciseCalculation' +
            ' algorithm_name and calculation_uuids are given' do
      before do
        algorithm_exercise_calculation_1 = FactoryBot.create(
          :algorithm_exercise_calculation,
          exercise_calculation: exercise_calculation_1, algorithm_name: given_algorithm_name
        )
        FactoryBot.create :assignment_pe,
                          algorithm_exercise_calculation: algorithm_exercise_calculation_1
        FactoryBot.create :assignment_spe,
                          algorithm_exercise_calculation: algorithm_exercise_calculation_1
        FactoryBot.create :student_pe,
                          algorithm_exercise_calculation: algorithm_exercise_calculation_1

        algorithm_exercise_calculation_2 = FactoryBot.create(
          :algorithm_exercise_calculation,
          exercise_calculation: exercise_calculation_2, algorithm_name: given_algorithm_name
        )
        FactoryBot.create :assignment_pe,
                          algorithm_exercise_calculation: algorithm_exercise_calculation_2
        FactoryBot.create :assignment_spe,
                          algorithm_exercise_calculation: algorithm_exercise_calculation_2
        FactoryBot.create :student_pe,
                          algorithm_exercise_calculation: algorithm_exercise_calculation_2
      end

      it 'updates the records and returns calculation_status: "calculation_accepted"' do
        expect { action }.to  not_change { AlgorithmExerciseCalculation.count }
                         .and change     { AssignmentPe.count  }.by(-2)
                         .and change     { AssignmentSpe.count }.by(-2)
                         .and change     { StudentPe.count     }.by(-2)

        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }

        algorithm_exercise_calculation_attributes = AlgorithmExerciseCalculation.pluck(
          :algorithm_name, :exercise_calculation_uuid, :ecosystem_matrix_uuid, :exercise_uuids
        )
        algorithm_exercise_calculation_attributes.each do |attributes|
          expect(algorithm_exercise_calculation_attributes_set).to include attributes
        end
      end
    end
  end
end
