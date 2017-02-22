require 'rake_helper'

RSpec.describe 'fetch_metadatas:courses', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  context 'with no course metadatas' do
    it 'does not create any courses' do
      expect { subject.invoke }.not_to change { Course.count }
    end
  end

  context 'with some exiting courses and course metadatas' do
    let!(:course_1)                 { FactoryGirl.create :course }
    let!(:course_2)                 { FactoryGirl.create :course }

    let(:existing_course_metadatas) do
      [ course_1, course_2 ].map do |course|
        { uuid: course.uuid, initial_ecosystem_uuid: course.ecosystem_uuid }
      end
    end
    let(:num_new_courses)           { 2 }
    let(:new_course_metadatas)      do
      num_new_courses.times.map do
        { uuid: SecureRandom.uuid, initial_ecosystem_uuid: SecureRandom.uuid }
      end
    end
    let(:course_metadatas)          { existing_course_metadatas + new_course_metadatas }
    let(:course_metadatas_response) { { course_responses: course_metadatas } }

    it 'creates all new courses' do
      expect(OpenStax::Biglearn::Api).to(
        receive(:fetch_course_metadatas).and_return(course_metadatas_response)
      )

      expect { subject.invoke }.to  change     { Course.count            }.by(num_new_courses)
                               .and not_change { course_1.reload.uuid    }
                               .and not_change { course_2.reload.uuid    }
                               .and not_change { course_1.ecosystem_uuid }
                               .and not_change { course_2.ecosystem_uuid }

      course_metadatas_by_uuid = new_course_metadatas.index_by { |metadata| metadata.fetch :uuid }
      new_courses = Course.where uuid: course_metadatas_by_uuid.keys
      new_courses.each do |course|
        metadata = course_metadatas_by_uuid.fetch(course.uuid)

        expect(course.ecosystem_uuid).to eq metadata.fetch(:initial_ecosystem_uuid)
        expect(course.sequence_number).to eq 0
        expect(course.course_excluded_exercise_uuids).to eq []
        expect(course.course_excluded_exercise_group_uuids).to eq []
        expect(course.global_excluded_exercise_uuids).to eq []
        expect(course.global_excluded_exercise_group_uuids).to eq []
      end
    end
  end
end
