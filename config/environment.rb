# Load the Rails application.
require_relative 'application'

require 'arel_trees'
require 'errors'
require 'values_table'
require 'worker'
require 'openstax/biglearn'
require 'tasks/application_helper'

# Initialize the Rails application.
Rails.application.initialize!
