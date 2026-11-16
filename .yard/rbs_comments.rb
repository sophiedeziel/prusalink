# frozen_string_literal: true

# yard doc reads .yardopts twice, which loads this file twice.
return if defined?(RbsCommentsDocstringParser)

# Keeps Sorbet's inline RBS signatures out of the generated documentation.
#
# Method signatures are written as `#:` comments (continued with `#|`) right
# above the `def`, so YARD reads them as the last lines of the doc comment
# and would print them in the method description. This parser drops that
# trailing signature block, and the RBS annotations written just above it
# (like `# @override(allow_incompatible: true)`), before YARD parses the
# docstring.
class RbsCommentsDocstringParser < YARD::DocstringParser
  SIGNATURE_LINE = /\A:(\s|$)/
  CONTINUATION_LINE = /\A\|/
  ANNOTATION_LINE = /\A@(abstract|final|override|overridable|without_runtime)\b/

  def parse(content, object = nil, handler = nil)
    super(strip_rbs_signature(content), object, handler)
  end

  private

  def strip_rbs_signature(content)
    return content unless content.is_a?(String)

    lines = content.lines
    index = skip_back(lines, lines.length - 1, CONTINUATION_LINE)
    return content unless index >= 0 && lines[index].match?(SIGNATURE_LINE)

    index = skip_back(lines, index - 1, ANNOTATION_LINE) + 1
    lines[0...index].join.rstrip
  end

  # Index of the last line at or before `index` that doesn't match `pattern`, or -1
  def skip_back(lines, index, pattern)
    index -= 1 while index >= 0 && lines[index].match?(pattern)
    index
  end
end

YARD::Docstring.default_parser = RbsCommentsDocstringParser
