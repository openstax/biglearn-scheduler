biglearn_secrets = Rails.application.secrets['openstax']['biglearn']

OpenStax::Biglearn::Api.configure do |config|
  config.server_url = biglearn_secrets['url']
  config.client_id  = biglearn_secrets['client_id']
  config.secret     = biglearn_secrets['secret']
end

biglearn_secrets.fetch('stub', false) ? OpenStax::Biglearn::Api.use_fake_client :
                                        OpenStax::Biglearn::Api.use_real_client
