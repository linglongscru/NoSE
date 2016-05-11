require 'codecov'

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CodeCov
]

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
end
