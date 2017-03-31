# Load the Rails application.
require_relative 'application'

require 'openstax/biglearn'
require 'worker'
require 'tasks/application_helper'

# Initialize the Rails application.
Rails.application.initialize!
