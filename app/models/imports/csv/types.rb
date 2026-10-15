module Imports
  module Csv
    module Types
      def self.registry
        Rails.application.config.x.csv_import_types.to_h
      end

      def self.fetch(key)
        adapter = registry.fetch(key)
        adapter.is_a?(String) ? adapter.constantize : adapter
      end

      def self.keys
        registry.keys
      end
    end
  end
end
