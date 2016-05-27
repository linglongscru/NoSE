require 'formatador'
require 'parallel'
require 'thor'
require 'yaml'

module NoSE
  # CLI tools for running the advisor
  module CLI
    # A command-line interface to running the advisor tool
    class NoSECLI < Thor
      # The path to the configuration file in the working directory
      CONFIG_FILE_NAME = 'nose.yml'

      check_unknown_options!

      class_option :debug, type: :boolean, aliases: '-d',
                           desc: 'enable detailed debugging information'
      class_option :parallel, type: :boolean, default: true,
                              desc: 'run various operations in parallel'
      class_option :colour, type: :boolean, default: nil, aliases: '-c',
                            desc: 'enabled coloured output'
      class_option :interactive, type: :boolean, default: true,
                                 desc: 'allow actions which require user input'

      def initialize(_options, local_options, config)
        super

        # Set up a logger for this command
        cmd_name = config[:current_command].name
        @logger = Logging.logger["nose::#{cmd_name}"]

        # Peek ahead into the options and prompt the user to create a config
        check_config_file interactive?(local_options)

        # Enable forcing the colour or no colour for output
        # We just lie to Formatador about whether or not $stdout is a tty
        unless options[:colour].nil?
          stdout_metaclass = class << $stdout; self; end
          method = options[:colour] ? ->() { true } : ->() { false }
          stdout_metaclass.send(:define_method, :tty?, &method)
        end

        # Disable parallel processing if desired
        Parallel.instance_variable_set(:@processor_count, 0) \
          unless options[:parallel]
      end

      private

      # Check if the user has disabled interaction
      def interactive?(options = [])
        parse_options = self.class.class_options
        opts = Thor::Options.new(parse_options).parse(options)
        opts[:interactive]
      end

      # Check if the user has created a configuration file
      def check_config_file(interactive)
        return if File.file?(CONFIG_FILE_NAME)

        if interactive
          no_create = no? 'nose.yml is missing, ' \
                          'create from nose.yml.example? [Yn]'
          FileUtils.cp 'nose.yml.example', CONFIG_FILE_NAME unless no_create
        else
          @logger.warn 'Configuration file missing'
        end
      end

      # Add the possibility to set defaults via configuration
      def options
        original_options = super
        return original_options unless File.exist? CONFIG_FILE_NAME
        defaults = YAML.load_file(CONFIG_FILE_NAME).deep_symbolize_keys || {}
        Thor::CoreExt::HashWithIndifferentAccess \
          .new(defaults.merge(original_options))
      end

      # Get a backend instance for a given configuration and dataset
      def get_backend(config, result)
        be_class = get_class 'backend', config
        be_class.new result.workload.model, result.indexes,
                     result.plans, result.update_plans, config[:backend]
      end

      # Get a class of a particular name from the configuration
      def get_class(class_name, config)
        name = config
        name = config[class_name.to_sym][:name] if config.is_a? Hash
        require_relative "#{class_name}/#{name}"
        name = name.split('_').map(&:capitalize).join
        full_class_name = ['NoSE', class_name.capitalize,
                           name + class_name.capitalize]
        full_class_name.reduce(Object) do |mod, name_part|
          mod.const_get name_part
        end
      end

      # Get a class given a set of options
      def get_class_from_config(options, name, type)
        cost_model_class = get_class name, options[type][:name]
        cost_model_class.new(**options[type])
      end

      # Collect all advisor results for schema design problem
      def search_result(workload, cost_model, max_space = Float::INFINITY,
                        objective = Search::Objective::COST,
                        by_id_path = false)
        enumerated_indexes = IndexEnumerator.new(workload) \
                             .indexes_for_workload([], by_id_path)
        Search::Search.new(workload, cost_model, objective, by_id_path) \
          .search_overlap enumerated_indexes.to_a, max_space
      end

      # Load results of a previous search operation
      def load_results(plan_file, mix)
        representer = Serialize::SearchResultRepresenter.represent \
          Search::Results.new
        json = File.read(plan_file)
        result = representer.from_json(json)
        result.workload.mix = mix.to_sym unless mix.nil? || \
          (mix == 'default' && result.workload.mix != :default)

        result
      end

      # Load plans either from an explicit file or the name
      # of something in the plans/ directory
      def load_plans(plan_file, options)
        if File.exist? plan_file
          result = load_results(plan_file, options[:mix])
        else
          schema = Schema.load plan_file
          result = OpenStruct.new
          result.workload = Workload.new schema.model
          result.indexes = schema.indexes.values
        end
        backend = get_backend(options, result)

        [result, backend]
      end

      # Output a list of indexes as text
      def output_indexes_txt(header, indexes, file)
        file.puts Formatador.parse("[blue]#{header}[/]")
        indexes.sort_by(&:key).each { |index| file.puts index.inspect }
        file.puts
      end

      # Output a list of query plans as text
      def output_plans_txt(plans, file, indent, weights)
        plans.each do |plan|
          weight = (plan.weight || weights[plan.query || plan.name])
          cost = plan.cost * weight

          file.puts "GROUP #{plan.group}" unless plan.group.nil?

          weight = " * #{weight} = #{cost}"
          file.puts '  ' * (indent - 1) + plan.query.inspect + weight
          plan.each { |step| file.puts '  ' * indent + step.inspect }
          file.puts
        end
      end

      # Output update plans as text
      def output_update_plans_txt(update_plans, file, weights, mix = nil)
        unless update_plans.empty?
          header = "Update plans\n" + '━' * 50
          file.puts Formatador.parse("[blue]#{header}[/]")
        end

        update_plans.group_by(&:statement).each do |statement, plans|
          if weights.key?(statement)
            weight = weights[statement]
          else
            weight =  weights[statement.group][mix]
          end
          total_cost = plans.sum_by(&:cost)

          file.puts "GROUP #{statement.group}" unless statement.group.nil?

          file.puts "#{statement.inspect} * #{weight} = #{total_cost * weight}"
          plans.each do |plan|
            file.puts Formatador.parse(" for [magenta]#{plan.index.key}[/] " \
                                       "[yellow]$#{plan.cost}[/]")
            query_weights = Hash[plan.query_plans.map do |query_plan|
              [query_plan.query, weight]
            end]
            output_plans_txt plan.query_plans, file, 2, query_weights

            plan.update_steps.each do |step|
              file.puts '  ' + step.inspect
            end

            file.puts
          end

          file.puts "\n"
        end
      end

      # Output the results of advising as text
      def output_txt(result, file = $stdout, enumerated = false)
        if enumerated
          header = "Enumerated indexes\n" + '━' * 50
          output_indexes_txt header, result.enumerated_indexes, file
        end

        # Output selected indexes
        header = "Indexes\n" + '━' * 50
        output_indexes_txt header, result.indexes, file

        file.puts Formatador.parse('  Total size: ' \
                                   "[blue]#{result.total_size}[/]\n\n")

        # Output query plans for the discovered indices
        header = "Query plans\n" + '━' * 50
        file.puts Formatador.parse("[blue]#{header}[/]")
        weights = result.workload.statement_weights
        weights = result.weights if weights.nil? || weights.empty?
        output_plans_txt result.plans, file, 1, weights

        result.update_plans = [] if result.update_plans.nil?
        output_update_plans_txt result.update_plans, file, weights,
                                result.workload.mix

        file.puts Formatador.parse('  Total cost: ' \
                                   "[blue]#{result.total_cost}[/]\n")
      end

      # Output the results of advising as JSON
      def output_json(result, file = $stdout, enumerated = false)
        # Temporarily remove the enumerated indexes
        if enumerated
          enumerated = result.enumerated_indexes
          result.delete_field :enumerated_indexes
        end

        file.puts JSON.pretty_generate \
          Serialize::SearchResultRepresenter.represent(result).to_hash

        result.enumerated_indexes = enumerated if enumerated
      end

      # Output the results of advising as YAML
      def output_yml(result, file = $stdout, enumerated = false)
        # Temporarily remove the enumerated indexes
        if enumerated
          enumerated = result.enumerated_indexes
          result.delete_field :enumerated_indexes
        end

        file.puts Serialize::SearchResultRepresenter.represent(result).to_yaml

        result.enumerated_indexes = enumerated if enumerated
      end

      # Filter an options hash for those only relevant to a given command
      def filter_command_options(opts, command)
        Thor::CoreExt::HashWithIndifferentAccess.new(opts.select do |key|
          self.class.commands[command].options \
            .each_key.map(&:to_sym).include? key.to_sym
        end)
      end
    end
  end
end

require_relative 'cli/shared_options'

# Require the various subcommands
require_relative 'cli/analyze'
require_relative 'cli/benchmark'
require_relative 'cli/collect_results'
require_relative 'cli/create'
require_relative 'cli/diff_plans'
require_relative 'cli/dump'
require_relative 'cli/export'
require_relative 'cli/execute'
require_relative 'cli/load'
require_relative 'cli/genworkload'
require_relative 'cli/graph'
require_relative 'cli/plan_schema'
require_relative 'cli/proxy'
require_relative 'cli/random_plans'
require_relative 'cli/reformat'
require_relative 'cli/repl'
require_relative 'cli/recost'
require_relative 'cli/search'
require_relative 'cli/search_all'
require_relative 'cli/search_bench'
require_relative 'cli/texify'
require_relative 'cli/why'

# Only include the console command if pry is available
begin
  require 'pry'
  require_relative 'cli/console'
rescue LoadError
  nil
end
