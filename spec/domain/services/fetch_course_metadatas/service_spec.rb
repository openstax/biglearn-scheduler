require 'rails_helper'

RSpec.describe Services::FetchCourseMetadatas::Service, type: :service do
  subject { described_class.new }

  context 'with no course metadatas' do
    it 'does not create any courses' do
      expect { subject.process }.not_to change { Course.count }
    end
  end

  context 'with some existing courses and course metadatas' do
    let!(:course_1)                 { FactoryBot.create :course }
    let!(:course_2)                 { FactoryBot.create :course }

    let(:existing_course_metadatas) do
      [ course_1, course_2 ].each_with_index.map do |course, index|
        {
          uuid: course.uuid,
          initial_ecosystem_uuid: course.ecosystem_uuid,
          metadata_sequence_number: index
        }
      end
    end
    let(:num_existing_courses)      { existing_course_metadatas.size }
    let(:num_new_courses)           { 2 }
    let(:new_course_metadatas)      do
      num_new_courses.times.map do |new_index|
        {
          uuid: SecureRandom.uuid,
          initial_ecosystem_uuid: SecureRandom.uuid,
          metadata_sequence_number: new_index + num_existing_courses
        }
      end
    end
    let(:course_metadatas)          { existing_course_metadatas + new_course_metadatas }
    let(:course_metadatas_response) { { course_responses: course_metadatas } }

    it 'creates all new courses' do
      expect(OpenStax::Biglearn::Api).to(
        receive(:fetch_course_metadatas).and_return(course_metadatas_response)
      )

      expect { subject.process }.to  change     { Course.count            }.by(num_new_courses)
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
