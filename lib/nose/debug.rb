require 'binding_of_caller'
require 'pry'

module NoSE
  # Various helpful debugging snippets
  module Debug
    # Convenience method to break in IndexLookupStep when
    # a particular set of indexes is reach when planning
    # @return [void]
    def self.break_on_indexes(*index_keys)
      apply = binding.of_caller(1)
      parent = apply.eval 'parent'
      index = apply.eval 'index'
      current_keys = parent.parent_steps.indexes.map(&:key) << index.key

      # rubocop:disable Lint/Debugger
      binding.pry if current_keys == index_keys
      # rubocop:enable Lint/Debugger
    end
  end
end