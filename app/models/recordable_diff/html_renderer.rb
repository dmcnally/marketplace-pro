class RecordableDiff::HtmlRenderer
  ParagraphOperation = Data.define(:action, :previous, :current)

  def initialize(previous:, current:, view_context:)
    @previous = previous.to_s
    @current = current.to_s
    @view_context = view_context
  end

  def render
    paragraph_diff.html_safe
  end

  private

  attr_reader :previous, :current, :view_context

  delegate :tag, to: :view_context

  def paragraph_diff
    previous_paragraphs = paragraphs(previous)
    current_paragraphs = paragraphs(current)

    paragraph_operations(previous_paragraphs, current_paragraphs).map do |operation|
      case operation.action
      when :equal
        escape(operation.current)
      when :delete
        tag.del(escape(operation.previous), class: "diffdel")
      when :insert
        tag.ins(escape(operation.current), class: "diffins")
      when :replace
        inline_html_diff(operation.previous, operation.current)
      end
    end.join("\n\n")
  end

  def inline_html_diff(previous_value, current_value)
    html = HTMLDiff::DiffBuilder.new(
      escape(previous_value),
      escape(current_value)
    ).build

    grouped_replacement_diff(html)
  end

  def paragraphs(value)
    value.split(/\n{2,}/)
  end

  def paragraph_operations(previous_paragraphs, current_paragraphs)
    costs, actions = paragraph_alignment_tables(previous_paragraphs, current_paragraphs)
    paragraph_alignment_operations(previous_paragraphs, current_paragraphs, actions, costs)
  end

  def paragraph_alignment_tables(previous_paragraphs, current_paragraphs)
    previous_count = previous_paragraphs.length
    current_count = current_paragraphs.length
    costs = Array.new(previous_count + 1) { Array.new(current_count + 1, 0.0) }
    actions = Array.new(previous_count + 1) { Array.new(current_count + 1) }

    1.upto(previous_count) do |index|
      costs[index][0] = index
      actions[index][0] = :delete
    end

    1.upto(current_count) do |index|
      costs[0][index] = index
      actions[0][index] = :insert
    end

    1.upto(previous_count) do |previous_index|
      1.upto(current_count) do |current_index|
        choose_paragraph_alignment(
          previous_paragraphs,
          current_paragraphs,
          costs,
          actions,
          previous_index,
          current_index
        )
      end
    end

    [ costs, actions ]
  end

  def choose_paragraph_alignment(previous_paragraphs, current_paragraphs, costs, actions, previous_index, current_index)
    previous_paragraph = previous_paragraphs[previous_index - 1]
    current_paragraph = current_paragraphs[current_index - 1]

    options = [
      [ costs[previous_index - 1][current_index] + 1.0, :delete ],
      [ costs[previous_index][current_index - 1] + 1.0, :insert ],
      [ costs[previous_index - 1][current_index - 1] + replacement_cost(previous_paragraph, current_paragraph), :replace ]
    ]
    cost, action = options.min_by(&:first)

    costs[previous_index][current_index] = cost
    actions[previous_index][current_index] = action
  end

  def paragraph_alignment_operations(previous_paragraphs, current_paragraphs, actions, costs)
    previous_index = previous_paragraphs.length
    current_index = current_paragraphs.length
    operations = []

    while previous_index.positive? || current_index.positive?
      action = actions[previous_index][current_index]

      case action
      when :replace
        operation = costs[previous_index][current_index] == costs[previous_index - 1][current_index - 1] ? :equal : :replace
        operations << ParagraphOperation.new(
          action: operation,
          previous: previous_paragraphs[previous_index - 1],
          current: current_paragraphs[current_index - 1]
        )
        previous_index -= 1
        current_index -= 1
      when :delete
        operations << ParagraphOperation.new(
          action: :delete,
          previous: previous_paragraphs[previous_index - 1],
          current: nil
        )
        previous_index -= 1
      when :insert
        operations << ParagraphOperation.new(
          action: :insert,
          previous: nil,
          current: current_paragraphs[current_index - 1]
        )
        current_index -= 1
      end
    end

    operations.reverse
  end

  def replacement_cost(previous_paragraph, current_paragraph)
    return 0.0 if previous_paragraph == current_paragraph

    similarity = paragraph_similarity(previous_paragraph, current_paragraph)
    return 2.1 if similarity < 0.25

    1.0 - similarity
  end

  def paragraph_similarity(previous_paragraph, current_paragraph)
    previous_words = normalized_words(previous_paragraph)
    current_words = normalized_words(current_paragraph)
    return 0.0 if previous_words.empty? || current_words.empty?

    overlap = (previous_words & current_words).length
    (2.0 * overlap) / (previous_words.length + current_words.length)
  end

  def normalized_words(value)
    value.downcase.scan(/[[:alnum:]]+/).uniq
  end

  def grouped_replacement_diff(html)
    nodes = Nokogiri::HTML.fragment(html).children.to_a
    rendered = []
    index = 0

    while index < nodes.length
      replacement_group = replacement_group_at(nodes, index)

      if replacement_group
        rendered << grouped_replacement_html(replacement_group)
        index = replacement_group[:next_index]
      else
        rendered << nodes[index].to_html
        index += 1
      end
    end

    rendered.join
  end

  def replacement_group_at(nodes, index)
    return unless replacement_delete?(nodes[index]) && replacement_insert?(nodes[index + 1])

    deleted = [ nodes[index].inner_html ]
    inserted = [ nodes[index + 1].inner_html ]
    cursor = index + 2

    while whitespace_node?(nodes[cursor]) &&
        replacement_delete?(nodes[cursor + 1]) &&
        replacement_insert?(nodes[cursor + 2])
      spacer = nodes[cursor].to_html
      deleted << spacer << nodes[cursor + 1].inner_html
      inserted << spacer << nodes[cursor + 2].inner_html
      cursor += 3
    end

    { deleted: deleted.join, inserted: inserted.join, next_index: cursor }
  end

  def grouped_replacement_html(replacement_group)
    normalized_replacement = normalized_replacement_group(replacement_group)

    [
      normalized_replacement[:prefix],
      replacement_delete_tag(normalized_replacement[:deleted]),
      replacement_insert_tag(normalized_replacement[:inserted]),
      normalized_replacement[:suffix]
    ].compact.join
  end

  def replacement_delete_tag(value)
    return if value.blank?

    tag.del(value.html_safe, class: "diffmod")
  end

  def replacement_insert_tag(value)
    return if value.blank?

    tag.ins(value.html_safe, class: "diffmod")
  end

  def normalized_replacement_group(replacement_group)
    deleted = replacement_group[:deleted]
    inserted = replacement_group[:inserted]
    prefix = common_word_prefix(deleted, inserted)
    suffix = common_word_suffix(deleted.delete_prefix(prefix), inserted.delete_prefix(prefix))
    punctuation = common_punctuation_suffix(deleted.delete_prefix(prefix).delete_suffix(suffix), inserted.delete_prefix(prefix).delete_suffix(suffix))
    suffix = "#{punctuation}#{suffix}"

    {
      prefix: prefix.presence,
      deleted: deleted.delete_prefix(prefix).delete_suffix(suffix),
      inserted: inserted.delete_prefix(prefix).delete_suffix(suffix),
      suffix: suffix.presence
    }
  end

  def common_word_prefix(deleted, inserted)
    limit = [ deleted.length, inserted.length ].min
    index = 0
    last_boundary = 0

    while index < limit && deleted[index] == inserted[index]
      index += 1
      last_boundary = index if word_boundary?(deleted, index)
    end

    deleted.first(last_boundary)
  end

  def common_word_suffix(deleted, inserted)
    limit = [ deleted.length, inserted.length ].min
    index = 0
    last_boundary = 0

    while index < limit && deleted[-index - 1] == inserted[-index - 1]
      index += 1
      last_boundary = index if word_boundary?(deleted, deleted.length - index)
    end

    return "" if last_boundary.zero?

    deleted.last(last_boundary)
  end

  def word_boundary?(value, index)
    return true if index.zero? || index == value.length

    value[index - 1].match?(/\s/) || value[index].match?(/\s/)
  end

  def common_punctuation_suffix(deleted, inserted)
    return "" if deleted.blank? || inserted.blank?

    deleted_last = deleted.last
    return "" unless deleted_last == inserted.last
    return "" unless deleted_last.match?(/[[:punct:]]/)

    deleted_last
  end

  def replacement_delete?(node)
    node&.element? && node.name == "del" && node["class"] == "diffmod"
  end

  def replacement_insert?(node)
    node&.element? && node.name == "ins" && node["class"] == "diffmod"
  end

  def whitespace_node?(node)
    node&.text? && node.text.match?(/\A\s+\z/)
  end

  def escape(value)
    ERB::Util.html_escape(value)
  end
end
