# Load the Rails application.
require_relative 'application'

require 'assignment_exercise_requests'
require 'errors'
require 'openstax/biglearn'
require 'tasks/application_helper'
require 'values_table'
require 'worker'

# Initialize the Rails application.
Rails.application.initialize!
