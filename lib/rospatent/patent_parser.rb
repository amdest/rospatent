# frozen_string_literal: true

module Rospatent
  # Module for parsing patent documents' XML content into structured formats
  module PatentParser
    # Extract and parse the abstract content from a patent document
    # @param patent_data [Hash] The patent document data returned by Client#patent method
    # @param format [Symbol] The desired output format (:text or :html)
    # @param language [String] The language code (e.g., "ru", "en")
    # @return [String, nil] The parsed abstract content in the requested format or nil if not found
    # @example Get plain text abstract
    #   abstract = PatentParser.parse_abstract(patent_doc)
    # @example Get HTML abstract in English
    #   abstract_html = PatentParser.parse_abstract(patent_doc, format: :html, language: "en")
    def self.parse_abstract(patent_data, format: :text, language: "ru")
      return nil unless patent_data && patent_data["abstract"] && patent_data["abstract"][language]

      abstract_xml = patent_data["abstract"][language]

      case format
      when :html
        # Extract the inner HTML content
        extract_inner_html(abstract_xml)
      else
        # Extract plain text
        extract_text_content(abstract_xml)
      end
    end

    # Extract and parse the description content from a patent document
    # @param patent_data [Hash] The patent document data returned by Client#patent method
    # @param format [Symbol] The desired output format (:text, :html, or :sections)
    # @param language [String] The language code (e.g., "ru", "en")
    # @return [String, Array, nil] The parsed description content in the requested format or nil if not found
    # @example Get plain text description
    #   description = PatentParser.parse_description(patent_doc)
    # @example Get HTML description
    #   description_html = PatentParser.parse_description(patent_doc, format: :html)
    # @example Get description split into sections
    #   sections = PatentParser.parse_description(patent_doc, format: :sections)
    def self.parse_description(patent_data, format: :text, language: "ru")
      unless patent_data && patent_data["description"] && patent_data["description"][language]
        return nil
      end

      description_xml = patent_data["description"][language]

      case format
      when :html
        # Extract the inner HTML content
        extract_inner_html(description_xml)
      when :sections
        # Split the description into numbered sections
        extract_description_sections(description_xml)
      else
        # Extract plain text
        extract_text_content(description_xml)
      end
    end

    class << self
      private

      # Extract plain text content from XML
      # @param xml_content [String] XML content
      # @return [String] Plain text content
      def extract_text_content(xml_content)
        # Remove XML tags and normalize whitespace
        text = xml_content.gsub(/<[^>]*>/, " ")
                          .gsub(/\s+/, " ")
                          .strip

        # Decode HTML entities
        decode_html_entities(text)
      end

      # Extract inner HTML content from XML
      # @param xml_content [String] XML content
      # @return [String] HTML content
      def extract_inner_html(xml_content)
        # Find content inside the main div tags
        if xml_content =~ %r{<div[^>]*>(.*)</div>}m
          ::Regexp.last_match(1).strip
        else
          # Fallback: return everything between the root element tags
          xml_content.sub(/^<[^>]*>/, "").sub(%r{</[^>]*>$}, "")
        end
      end

      # Extract sections from description XML
      # @param xml_content [String] XML description content
      # @return [Array<Hash>] Array of section hashes with number and content
      def extract_description_sections(xml_content)
        sections = []

        # Extract each div block which represents a section
        xml_content.scan(%r{<div[^>]*>.*?</div>}m) do |div|
          # Extract section number from the span tag
          section_number = if div =~ %r{<span[^>]*>\[(\d+)\]</span>}
                             ::Regexp.last_match(1).to_i
                           else
                             sections.size + 1
                           end

          # Extract paragraph content
          content = if div =~ %r{<p[^>]*>(.*?)</p>}m
                      ::Regexp.last_match(1).strip
                    else
                      # Fallback
                      div.gsub(%r{<span[^>]*>.*?</span>}m, "").gsub(%r{</?div[^>]*>}, "").strip
                    end

          sections << {
            number: section_number,
            content: decode_html_entities(content.gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip)
          }
        end

        # Sort by section number
        sections.sort_by { |section| section[:number] }
      end

      # Decode HTML entities in text
      # @param text [String] Text with HTML entities
      # @return [String] Text with decoded HTML entities
      def decode_html_entities(text)
        text.gsub(/&([a-z]+);/i) do |entity|
          case ::Regexp.last_match(1).downcase
          when "lt" then "<"
          when "gt" then ">"
          when "amp" then "&"
          when "quot" then '"'
          when "apos" then "'"
          when "nbsp" then " "
          else entity
          end
        end
      end
    end
  end
end
