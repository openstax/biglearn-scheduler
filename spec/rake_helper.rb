# https://robots.thoughtbot.com/test-rake-tasks-like-a-boss
require 'rails_helper'

RSpec.shared_context 'rake' do
  subject      { Rake.application[@task_name] }

  before(:all) do
    @previous_rake_application = Rake.application

    @task_name = self.class.top_level_description
    task_path = File.join 'lib', 'tasks', *@task_name.split(':')
    loaded_files_excluding_current_rake_file = \
      $".reject { |file| file == Rails.root.join("#{task_path}.rake").to_s }

    Rake.application = Rake::Application.new
    Rake.application.rake_require(
      task_path, [Rails.root.to_s], loaded_files_excluding_current_rake_file
    )

    Rake::Task.define_task :environment
  end

  before       { subject.reenable }

  after(:all)  { Rake.application = @previous_rake_application }
end
