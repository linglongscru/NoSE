require 'mongo'

module NoSE
  module Backend
    # A backend which communicates with MongoDB
    class MongoBackend < BackendBase
      def initialize(model, indexes, plans, update_plans, config)
        super

        @uri = config[:uri]
      end

      # Create new MongoDB collections for each index
      def indexes_ddl(execute = false, skip_existing = false,
                      drop_existing = false)
        ddl = []

        # Create the ID paths for all indexes
        id_paths = @indexes.map(&:to_id_path).uniq
        id_paths.map do |id_path|
          ddl << "Create #{id_path.key}"
          next unless execute

          collection = client.collections.find { |c| c.name == id_path.key }
          collection.drop if drop_existing && !collection.nil?
          client[id_path.key].create unless skip_existing
        end

        # Create any necessary indexes on the ID paths
        @indexes. each do |index|
          id_path = index.to_id_path
          next if id_path == index

          # Index keys are any non-ID fields
          keys = (index.hash_fields.to_a + index.order_fields).reject do |key|
            key.is_a? Fields::IDField
          end

          # Combine the key paths for all fields to create a compound index
          index_spec = Hash[keys.map do |key|
            [index.path.path_for_field(key).join('.'), 1]
          end]

          ddl << "Add index #{index_spec} to #{id_path.key}"
          next unless execute

          client[id_path.key].indexes.create_one index_spec
        end

        ddl
      end

      private

      # Create a Mongo client from the saved config
      def client
        @client ||= Mongo::Client.new @uri
      end
    end
  end
end
