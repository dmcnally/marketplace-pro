# htmldiff 0.0.1 mutates string literals while tokenizing HTML, which emits
# noisy Ruby 3.4 warnings about future frozen string behavior.
if defined?(HTMLDiff::DiffBuilder) && Gem.loaded_specs["htmldiff"]&.version == Gem::Version.new("0.0.1")
  class HTMLDiff::DiffBuilder
    def convert_html_to_list_of_words(x, use_brackets = false)
      mode = :char
      current_word = String.new
      words = []

      explode(x).each do |char|
        case mode
        when :tag
          if end_of_tag? char
            current_word << (use_brackets ? "]" : ">")
            words << current_word
            current_word = String.new
            if whitespace?(char)
              mode = :whitespace
            else
              mode = :char
            end
          else
            current_word << char
          end
        when :char
          if start_of_tag? char
            words << current_word unless current_word.empty?
            current_word = (use_brackets ? "[" : "<").dup
            mode = :tag
          elsif /\s/.match char
            words << current_word unless current_word.empty?
            current_word = char.dup
            mode = :whitespace
          else
            current_word << char
          end
        when :whitespace
          if start_of_tag? char
            words << current_word unless current_word.empty?
            current_word = (use_brackets ? "[" : "<").dup
            mode = :tag
          elsif /\s/.match char
            current_word << char
          else
            words << current_word unless current_word.empty?
            current_word = char.dup
            mode = :char
          end
        else
          raise "Unknown mode #{mode.inspect}"
        end
      end

      words << current_word unless current_word.empty?
      words
    end
  end
end
