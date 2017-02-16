require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.allow_http_connections_when_no_cassette = false
  c.ignore_localhost = true
end

VCR_OPTS = {
  # This should default to :none before pushing
  record: ENV["VCR_OPTS_RECORD"].try(:to_sym) || :none,
  allow_unused_http_interactions: false
}
