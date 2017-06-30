biglearn_api_secrets = Rails.application.secrets['openstax']['biglearn']['api']

OpenStax::Biglearn::Api.configure do |config|
  config.server_url = biglearn_api_secrets['url']
  config.token      = biglearn_api_secrets['token']
  config.client_id  = biglearn_api_secrets['client_id']
  config.secret     = biglearn_api_secrets['secret']
end

biglearn_api_secrets.fetch('stub', false) ? OpenStax::Biglearn::Api.use_fake_client :
                                            OpenStax::Biglearn::Api.use_real_client
