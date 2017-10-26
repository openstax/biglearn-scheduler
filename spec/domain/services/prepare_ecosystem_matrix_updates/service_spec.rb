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

      @ecosystem_1 = FactoryGirl.create :ecosystem
      @ecosystem_2 = FactoryGirl.create :ecosystem
      @ecosystem_3 = FactoryGirl.create :ecosystem
      @ecosystem_4 = FactoryGirl.create :ecosystem

      @ecosystem_exercise_1 = FactoryGirl.create :ecosystem_exercise,
                                                 ecosystem_uuid: @ecosystem_1.uuid,
                                                 next_ecosystem_matrix_update_response_count: 1
      @ecosystem_exercise_2 = FactoryGirl.create :ecosystem_exercise,
                                                 ecosystem_uuid: @ecosystem_2.uuid,
                                                 next_ecosystem_matrix_update_response_count: 2
      @ecosystem_exercise_3 = FactoryGirl.create :ecosystem_exercise,
                                                 ecosystem_uuid: @ecosystem_3.uuid,
                                                 next_ecosystem_matrix_update_response_count: 1
      exercise_group = FactoryGirl.create :exercise_group, used_in_ecosystem_matrix_updates: false
      exercise = FactoryGirl.create :exercise, exercise_group: exercise_group
      @ecosystem_exercise_4 = FactoryGirl.create :ecosystem_exercise,
                                                 ecosystem_uuid: @ecosystem_4.uuid,
                                                 exercise: exercise

      @response_1 = FactoryGirl.create :response,
                                       ecosystem_uuid: @ecosystem_exercise_1.ecosystem_uuid,
                                       exercise_uuid: @ecosystem_exercise_1.exercise_uuid,
                                       used_in_response_count: false
      @response_2 = FactoryGirl.create :response,
                                       ecosystem_uuid: @ecosystem_exercise_2.ecosystem_uuid,
                                       exercise_uuid: @ecosystem_exercise_2.exercise_uuid,
                                       used_in_response_count: false

      @response_3 = FactoryGirl.create :response,
                                       ecosystem_uuid: @ecosystem_exercise_2.ecosystem_uuid,
                                       exercise_uuid: @ecosystem_exercise_2.exercise_uuid,
                                       used_in_response_count: true
    end

    after(:all)  { DatabaseCleaner.clean }

    it 'marks the Response objects as processed' do
      expect do
        subject.process
      end.to  change     { @response_1.reload.used_in_response_count }.from(false).to(true)
         .and change     { @response_2.reload.used_in_response_count }.from(false).to(true)
         .and not_change { @response_3.reload.used_in_response_count }
    end

    it 'creates EcosystemMatrixUpdate records when the next update response counts are reached' do
      expect { subject.process }.to  not_change { Response.count                       }
                                .and change     { EcosystemMatrixUpdate.count          }.by(3)
                                .and not_change { AlgorithmEcosystemMatrixUpdate.count }
    end

    context 'with existing EcosystemMatrixUpdates and AlgorithmEcosystemMatrixUpdates' do
      before(:all) do
        DatabaseCleaner.start

        @ecosystem_matrix_update_1 = FactoryGirl.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_1.uuid
        @ecosystem_matrix_update_2 = FactoryGirl.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_2.uuid
        @ecosystem_matrix_update_3 = FactoryGirl.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_3.uuid

        @algorithm_ecosystem_matrix_update_1 =
          FactoryGirl.create :algorithm_ecosystem_matrix_update,
                             ecosystem_matrix_update: @ecosystem_matrix_update_1
        @algorithm_ecosystem_matrix_update_2 =
          FactoryGirl.create :algorithm_ecosystem_matrix_update,
                             ecosystem_matrix_update: @ecosystem_matrix_update_2
        @algorithm_ecosystem_matrix_update_3 =
          FactoryGirl.create :algorithm_ecosystem_matrix_update,
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
