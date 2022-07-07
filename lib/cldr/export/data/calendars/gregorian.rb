# frozen_string_literal: true

module Cldr
  module Export
    module Data
      class Calendars
        class Gregorian < Base
          def initialize(locale)
            super
            update(
              months: contexts("month"),
              days: contexts("day"),
              eras: eras,
              quarters: contexts("quarter"),
              periods: contexts("dayPeriod", group: "alt"),
              fields: fields,
              formats: {
                date: formats("date"),
                time: formats("time"),
                datetime: formats("dateTime"),
              },
              additional_formats: additional_formats
            )
          end

          def calendar
            @calendar ||= select('dates/calendars/calendar[@type="gregorian"]').first
          end

          def contexts(kind, options = {})
            select(calendar, "#{kind}s/#{kind}Context").each_with_object({}) do |node, result|
              context = node.attribute("type").value.to_sym
              result[context] = widths(node, kind, context, options)
            end
          end

          def widths(node, kind, context, options = {})
            select(node, "#{kind}Width").each_with_object({}) do |node, result|
              width = node.attribute("type").value.to_sym
              result[width] = elements(node, kind, context, width, options)
            end
          end

          def elements(node, kind, context, width, options = {})
            aliased = select(node, "alias").first

            if aliased
              xpath_to_key(aliased.attribute("path").value, kind, context, width)
            else
              select(node, kind).each_with_object({}) do |node, result|
                key = node.attribute("type").value
                key = key =~ /^\d*$/ ? key.to_i : key.to_sym

                if options[:group] && (found_group = node.attribute(options[:group]))
                  result[found_group.value] ||= {}
                  result[found_group.value][key] = node.content
                else
                  result[key] = node.content
                end
              end
            end
          end

          def xpath_to_key(xpath, kind, context, width)
            kind    = (xpath =~ %r(/([^\/]*)Width) && Regexp.last_match(1)) || kind
            context = (xpath =~ %r(Context\[@type='([^\/]*)'\]) && Regexp.last_match(1)) || context
            width   = (xpath =~ %r(Width\[@type='([^\/]*)'\]) && Regexp.last_match(1)) || width
            :"calendars.gregorian.#{kind}s.#{context}.#{width}"
          end

          def xpath_width
          end

          def periods
            am = select(calendar, "am").first
            pm = select(calendar, "pm").first

            result = {}
            result[:am] = am.content if am
            result[:pm] = pm.content if pm
            result
          end

          def eras
            if calendar
              base_path = calendar.path.sub(%r{^/ldml/}, "") + "/eras"
              keys = select("#{base_path}/*").map(&:name)

              keys.each_with_object({}) do |name, result|
                path = "#{base_path}/#{name}/*"
                key  = name.gsub("era", "").gsub(/s$/, "").downcase.to_sym

                key_result = select(path).each_with_object({}) do |node, ret|
                  if node.name == "alias"
                    target = (node.attribute("path").value.match(%r{/([^\/]+)$}) && Regexp.last_match(1)).gsub("era", "").gsub(/s$/, "").downcase
                    break :"calendars.gregorian.eras.#{target}"
                  end

                  type = node.attribute("type").value.to_i
                  ret[type] = node.content
                end
                result[key] = key_result unless key_result.empty?
              end
            else
              {}
            end
          end

          def extract(path, lambdas)
            nodes = select(path)
            nodes.each_with_object({}) do |node, ret|
              key = lambdas[:key].call(node)
              ret[key] = lambdas[:value].call(node)
            end
          end

          def formats(type)
            formats = select(calendar, "#{type}Formats/#{type}FormatLength").each_with_object({}) do |node, result|
              key = node.attribute("type").value.to_sym
              result[key] = pattern(node, type)
            end
            if (default = default_format(type))
              formats = default.merge(formats)
            end
            formats
          end

          def additional_formats
            select(calendar, "dateTimeFormats/availableFormats/dateFormatItem").each_with_object({}) do |node, result|
              key = node.attribute("id").value
              result[key] = node.content
            end
          end

          def default_format(type)
            if (node = select(calendar, "#{type}Formats/default").first)
              key = node.attribute("choice").value.to_sym
              { default: :"calendars.gregorian.formats.#{type.downcase}.#{key}" }
            end
          end

          def pattern(node, type)
            select(node, "#{type}Format/pattern").each_with_object({}) do |node, result|
              pattern = node.content
              pattern = pattern.gsub("{0}", "{{time}}").gsub("{1}", "{{date}}") if type == "dateTime"
              result[:pattern] = pattern
            end
          end

          # NOTE: As of CLDR 23, this data moved from inside each "calendar" tag to under its parent, the "dates" tag.
          # That probably means this `fields` method should be moved up to the parent as well.
          def fields
            select("dates/fields/field").each_with_object({}) do |node, result|
              key  = node.attribute("type").value.to_sym
              name = node.xpath("displayName").first
              result[key] = name.content if name
            end
          end
        end
      end
    end
  end
end
