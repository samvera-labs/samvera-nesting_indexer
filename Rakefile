require "bundler/gem_tasks"
require "rspec/core/rake_task"

namespace :commitment do
  require 'rubocop/rake_task'
  # Why hound? Because hound-ci assumes this file, and perhaps you'll be using this
  RuboCop::RakeTask.new do |task|
    task.options = ['--display-cop-names']
  end

  task :configure_test_for_code_coverage do
    ENV['COVERAGE'] = 'true'
  end
  task :code_coverage do
    require 'json'
    $stdout.puts "Checking commitment:code_coverage"
    coverage_percentage = JSON.parse(File.read('coverage/.last_run.json')).fetch('result').fetch('covered_percent').to_i
    goal = 100
    abort("Code Coverage Goal Not Met:\n\t#{coverage_percentage}%\tExpected\n\t#{goal}%\tActual") if goal > coverage_percentage
  end
end

task(
  all_specs: [
    'commitment:rubocop',
    'commitment:configure_test_for_code_coverage',
    'spec',
    'commitment:code_coverage'
  ]
)

task default: :all_specs

RSpec::Core::RakeTask.new(:spec)

task build: :all_specs
task release: :all_specs
