namespace :course do
  task fetch_metadatas: :environment do
    OpenStax::Biglearn::Api.fetch_course_metadatas.each do |course|
    end
  end
end
