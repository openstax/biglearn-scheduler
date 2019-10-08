require 'rails_helper'

RSpec.describe Services::CleanupExerciseCalculations::Service, type: :service do
  let(:service) { described_class.new }

  let!(:new_non_superseded_exercise_calculation) { FactoryBot.create :exercise_calculation }
  let!(:new_non_superseded_algorithm_exercise_calculation) do
    FactoryBot.create :algorithm_exercise_calculation,
                      exercise_calculation: new_non_superseded_exercise_calculation
  end
  let!(:new_superseded_exercise_calculation_with_assignments) do
    FactoryBot.create :exercise_calculation, superseded_by: new_non_superseded_exercise_calculation,
                                             is_used_in_assignments: true
  end
  let!(:new_superseded_algorithm_exercise_calculation_with_assignments) do
    FactoryBot.create :algorithm_exercise_calculation,
                      exercise_calculation: new_superseded_exercise_calculation_with_assignments
  end
  let!(:new_superseded_exercise_calculation_without_assignments) do
    FactoryBot.create :exercise_calculation, superseded_by: new_non_superseded_exercise_calculation,
                                             is_used_in_assignments: false
  end
  let!(:new_superseded_algorithm_exercise_calculation_without_assignments) do
    FactoryBot.create :algorithm_exercise_calculation,
                      exercise_calculation: new_superseded_exercise_calculation_without_assignments
  end

  let(:month_ago) { Time.current - 1.month }

  let!(:old_non_superseded_exercise_calculation) do
    FactoryBot.create :exercise_calculation, created_at: month_ago, updated_at: month_ago
  end
  let!(:old_non_superseded_algorithm_exercise_calculation) do
    FactoryBot.create :algorithm_exercise_calculation,
                      exercise_calculation: old_non_superseded_exercise_calculation
  end
  let!(:old_superseded_exercise_calculation_with_assignments) do
    FactoryBot.create :exercise_calculation, superseded_by: old_non_superseded_exercise_calculation,
                                             is_used_in_assignments: true,
                                             created_at: month_ago,
                                             updated_at: month_ago
  end
  let!(:old_superseded_algorithm_exercise_calculation_with_assignments) do
    FactoryBot.create :algorithm_exercise_calculation,
                      exercise_calculation: old_superseded_exercise_calculation_with_assignments
  end
  let!(:old_superseded_exercise_calculation_without_assignments) do
    FactoryBot.create :exercise_calculation, superseded_by: old_non_superseded_exercise_calculation,
                                             is_used_in_assignments: false,
                                             created_at: month_ago,
                                             updated_at: month_ago
  end
  let!(:old_superseded_algorithm_exercise_calculation_without_assignments) do
    FactoryBot.create :algorithm_exercise_calculation,
                      exercise_calculation: old_superseded_exercise_calculation_without_assignments
  end

  let(:action) { service.process }

  it 'removes only old superseded (algorithm) exercise calculations without assignments' do
    expect { action }.to  change { ExerciseCalculation.count }.by(-1)
                     .and change { AlgorithmExerciseCalculation.count }.by(-1)

    expect do
      old_superseded_exercise_calculation_without_assignments.reload
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect do
      old_superseded_algorithm_exercise_calculation_without_assignments.reload
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
