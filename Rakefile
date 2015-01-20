require 'rspec/core/rake_task'
require 'yard'
require 'yard-thor'

# XXX: Patch OpenStruct for yard-thor
class OpenStruct
  def delete(name)
    delete_field name
  end
end

RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = "--tag ~gurobi"
end
YARD::Rake::YardocTask.new(:doc)

task :console do
  require 'irb'
  require 'irb/completion'
  require_relative './lib/nose'
  ARGV.clear
  IRB.start
end

task default: :spec
