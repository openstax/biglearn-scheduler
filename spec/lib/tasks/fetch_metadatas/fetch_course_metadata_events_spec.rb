require 'vcr_helper'
require 'rake_helper'

RSpec.describe 'fetch_metadatas:fetch_course_metadata_events', type: :task, vcr: VCR_OPTS do
  include_context 'rake'

  before(:each) { OpenStax::Biglearn::Api.use_real_client }
  after(:each) { OpenStax::Biglearn::Api.use_fake_client }

  it 'imports' do
    expect {
      subject.invoke(4291, 1)
    }.to change { Course.count }.by 1
  end
end
