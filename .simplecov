require 'codeclimate-test-reporter'

SimpleCov.start do
  add_filter '/spec/'
  skip_token CodeClimate::TestReporter.configuration.skip_token
  formatter SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::HTMLFormatter,
    CodeClimate::TestReporter::Formatter
  ]
end
