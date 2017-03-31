# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
require 'tasks/application_helper'

# Override the output formatter setting in .rspec
task(:spec) { ENV['SPEC_OPTS'] ||= '--format progress' }

Rails.application.load_tasks
