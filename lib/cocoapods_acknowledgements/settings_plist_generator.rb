# frozen_string_literal: true
require 'cocoapods_acknowledgements/plist_generator'

module CocoaPodsAcknowledgements
  class SettingsPlistGenerator < PlistGenerator
    class << self

      def generate(target_description, sandbox, excluded)
        root_specs = target_description.specs.map(&:root).uniq.reject { |spec| excluded.include?(spec.name) }

        return nil if root_specs.empty?

        specs_metadata = [header]

        root_specs.each do |spec|
          platform = Pod::Platform.new(target_description.platform_name)
          file_accessor = file_accessor(spec, platform, sandbox)
          license_text = license_text(spec, file_accessor)

          spec_metadata = {
            "Title" => spec.name,
            "Type" => "PSGroupSpecifier",
            "FooterText" => license_text
          }
          specs_metadata << spec_metadata
        end

        specs_metadata << footer
        {
          "PreferenceSpecifiers" => specs_metadata,
          "Title" => "Acknowledgements",
          "StringsTable" => "Acknowledgements"
        }
      end

      def header
        {
          "FooterText" => "This application makes use of the following third party libraries:",
          "Title" => "Acknowledgements",
          "Type" => "PSGroupSpecifier"
        }
      end

      def footer
        {
          "FooterText" => "Generated by CocoaPods - https://cocoapods.org",
          "Title" => nil,
          "Type" => "PSGroupSpecifier"
        }
      end
    end
  end
end
