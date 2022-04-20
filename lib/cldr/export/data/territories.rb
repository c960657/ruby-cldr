# frozen_string_literal: true

module Cldr
  module Export
    module Data
      class Territories < Base
        def initialize(locale)
          super
          update(territories: territories)
        end

        private

        def territories
          @territories ||= select("localeDisplayNames/territories/territory").each_with_object({}) do |node, result|
            result[node.attribute("type").value.to_sym] = node.content unless alt?(node)
          end
        end
      end
    end
  end
end
