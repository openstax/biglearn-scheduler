require 'rails_helper'

RSpec.describe Services::PrepareEcosystemMatrixUpdates::Service, type: :service do
  subject { described_class.new }

  context 'with no Ecosystems, EcosystemExercises or Responses' do
    it 'does not request any ecosystem matrix updates' do
      expect { subject.process }.to  not_change { Response.count                       }
                                .and not_change { EcosystemMatrixUpdate.count          }
                                .and not_change { AlgorithmEcosystemMatrixUpdate.count }
    end
  end

  context 'with existing Ecosystems, EcosystemExercises and Responses' do
    before(:all) do
      DatabaseCleaner.start

      @ecosystem_1 = FactoryBot.create :ecosystem
      @ecosystem_2 = FactoryBot.create :ecosystem
      @ecosystem_3 = FactoryBot.create :ecosystem
      @ecosystem_4 = FactoryBot.create :ecosystem

      exercise_group_1 = FactoryBot.create :exercise_group, next_update_response_count: 1,
                                                             trigger_ecosystem_matrix_update: false
      exercise_1 = FactoryBot.create :exercise, exercise_group: exercise_group_1
      @ecosystem_exercise_1 = FactoryBot.create :ecosystem_exercise,
                                                 ecosystem: @ecosystem_1,
                                                 exercise: exercise_1

      exercise_group_2 = FactoryBot.create :exercise_group, next_update_response_count: 2,
                                                             trigger_ecosystem_matrix_update: false
      exercise_2 = FactoryBot.create :exercise, exercise_group: exercise_group_2
      @ecosystem_exercise_2 = FactoryBot.create :ecosystem_exercise,
                                                 ecosystem: @ecosystem_2,
                                                 exercise: exercise_2

      exercise_group_3 = FactoryBot.create :exercise_group, next_update_response_count: 1,
                                                             trigger_ecosystem_matrix_update: false
      exercise_3 = FactoryBot.create :exercise, exercise_group: exercise_group_3
      @ecosystem_exercise_3 = FactoryBot.create :ecosystem_exercise,
                                                 ecosystem: @ecosystem_3,
                                                 exercise: exercise_3

      exercise_group_4 = FactoryBot.create :exercise_group, trigger_ecosystem_matrix_update: true
      exercise_4 = FactoryBot.create :exercise, exercise_group: exercise_group_4
      @ecosystem_exercise_4 = FactoryBot.create :ecosystem_exercise,
                                                 ecosystem: @ecosystem_4,
                                                 exercise: exercise_4

      @response_1 = FactoryBot.create :response,
                                       ecosystem_uuid: @ecosystem_exercise_1.ecosystem_uuid,
                                       exercise_uuid: @ecosystem_exercise_1.exercise_uuid,
                                       is_used_in_response_count: false
      @response_2 = FactoryBot.create :response,
                                       ecosystem_uuid: @ecosystem_exercise_2.ecosystem_uuid,
                                       exercise_uuid: @ecosystem_exercise_2.exercise_uuid,
                                       is_used_in_response_count: false

      @response_3 = FactoryBot.create :response,
                                       ecosystem_uuid: @ecosystem_exercise_2.ecosystem_uuid,
                                       exercise_uuid: @ecosystem_exercise_2.exercise_uuid,
                                       is_used_in_response_count: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it 'marks the Response objects as processed' do
      expect do
        subject.process
      end.to  change     { @response_1.reload.is_used_in_response_count }.from(false).to(true)
         .and change     { @response_2.reload.is_used_in_response_count }.from(false).to(true)
         .and not_change { @response_3.reload.is_used_in_response_count }
    end

    it 'creates EcosystemMatrixUpdate records when the next update response counts are reached' do
      expect { subject.process }.to  not_change { Response.count                       }
                                .and change     { EcosystemMatrixUpdate.count          }.by(3)
                                .and not_change { AlgorithmEcosystemMatrixUpdate.count }
    end

    context 'with existing EcosystemMatrixUpdates and AlgorithmEcosystemMatrixUpdates' do
      before(:all) do
        DatabaseCleaner.start

        @ecosystem_matrix_update_1 = FactoryBot.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_1.uuid
        @ecosystem_matrix_update_2 = FactoryBot.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_2.uuid
        @ecosystem_matrix_update_3 = FactoryBot.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_3.uuid

        @algorithm_ecosystem_matrix_update_1 =
          FactoryBot.create :algorithm_ecosystem_matrix_update,
                             ecosystem_matrix_update: @ecosystem_matrix_update_1
        @algorithm_ecosystem_matrix_update_2 =
          FactoryBot.create :algorithm_ecosystem_matrix_update,
                             ecosystem_matrix_update: @ecosystem_matrix_update_2
        @algorithm_ecosystem_matrix_update_3 =
          FactoryBot.create :algorithm_ecosystem_matrix_update,
                             ecosystem_matrix_update: @ecosystem_matrix_update_3
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'upserts EcosystemMatrixUpdates and deletes AlgorithmEcosystemMatrixUpdates' do
        expect { subject.process }.to  not_change { Response.count                       }
                                  .and change     { EcosystemMatrixUpdate.count          }.by(1)
                                  .and change     { AlgorithmEcosystemMatrixUpdate.count }.by(-2)
      end
    end
  end
end
