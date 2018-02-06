module Prawn::SVG::CSS
  class Stylesheets
    attr_reader :css_parser, :root, :media

    def initialize(css_parser, root, media = :all)
      @css_parser = css_parser
      @root = root
      @media = media
    end

    def load
      load_style_elements
      xpath_styles = gather_xpath_styles
      associate_xpath_styles_with_elements(xpath_styles)
    end

    private

    def load_style_elements
      REXML::XPath.match(root, '//style').each do |source|
        data = source.texts.map(&:value).join
        css_parser.add_block!(data)
      end
    end

    def gather_xpath_styles
      xpath_styles = []
      order = 0

      css_parser.each_rule_set(media) do |rule_set, _|
        declarations = []
        rule_set.each_declaration { |*data| declarations << data }

        rule_set.selectors.each do |selector_text|
          selector = Prawn::SVG::CSS::SelectorParser.parse(selector_text)
          xpath = css_selector_to_xpath(selector)
          specificity = calculate_specificity(selector)
          specificity << order
          order += 1

          xpath_styles << [xpath, declarations, specificity]
        end
      end

      xpath_styles.sort_by(&:last)
    end

    def associate_xpath_styles_with_elements(xpath_styles)
      element_styles = {}

      xpath_styles.each do |xpath, declarations, _|
        REXML::XPath.match(root, xpath).each do |element|
          (element_styles[element] ||= []).concat declarations
        end
      end

      element_styles
    end

    def css_selector_to_xpath(selector)
      selector.map do |element|
        result = "#{element[:association] == :child ? "/" : "//"}#{element[:name]}"
        result << ((element[:class] || []).map { |name| "[contains(concat(' ',@class,' '), ' #{name} ')]" }.join)
        result << ((element[:id] || []).map { |name| "[@id='#{name}']" }.join)
        result
      end.join
    end

    def calculate_specificity(selector)
      selector.reduce([0, 0, 0]) do |(a, b, c), element|
        [
          a + (element[:id] || []).length,
          b + (element[:class] || []).length,
          c + (element[:name] && element[:name] != "*" ? 1 : 0)
        ]
      end
    end
  end
end
