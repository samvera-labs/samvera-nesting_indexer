require "bundler/gem_tasks"
require "rspec/core/rake_task"

namespace :commitment do
  require 'rubocop/rake_task'
  # Why hound? Because hound-ci assumes this file, and perhaps you'll be using this
  RuboCop::RakeTask.new

  task :configure_test_for_code_coverage do
    ENV['COVERAGE'] = 'true'
  end
  task :code_coverage do
    require 'json'
    $stdout.puts "Checking commitment:code_coverage"
    coverage_percentage = JSON.parse(File.read('coverage/.last_run.json')).fetch('result').fetch('covered_percent').to_i
    goal = 100
    if goal > coverage_percentage
      abort("Code Coverage Goal Not Met:\n\t#{coverage_percentage}%\tExpected\n\t#{goal}%\tActual")
    end
  end
end

task(
  default: [
    'commitment:rubocop',
    'commitment:configure_test_for_code_coverage',
    'spec',
    'commitment:code_coverage'
  ]
)

RSpec::Core::RakeTask.new(:spec)

task default: :spec
