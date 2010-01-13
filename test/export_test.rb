# encoding: utf-8

require File.dirname(__FILE__) + '/test_helper.rb'
require 'yaml'
require 'fileutils'

class TestExtract < Test::Unit::TestCase
  def setup
    Cldr::Export.base_path = tmp_dir
    FileUtils.mkdir_p(tmp_dir) rescue nil
  end

  def teardown
    FileUtils.rm_r(tmp_dir)
  end

  def tmp_dir
    File.expand_path(File.dirname(__FILE__) + '/tmp')
  end

  define_method 'test: passing the merge option generates and merge data for all fallback locales' do
    data = Cldr::Export.data('numbers', 'de-AT')
    assert !data[:numbers][:formats][:nan]

    data = Cldr::Export.data('numbers', 'de-AT', :merge => true)
    assert_equal 'NaN', data[:numbers][:symbols][:nan]
  end

  define_method "test: exports data to files" do
    Cldr::Export.export(:locales => %w(de), :components => %w(calendars))
    assert File.exists?(Cldr::Export.path('de', 'calendars', 'yml'))
  end

  define_method "test: exported data starts with the locale at top level" do
    Cldr::Export.export(:locales => %w(de), :components => %w(calendars))
    data = YAML.load(File.open(Cldr::Export.path('de', 'calendars', 'yml')))
    assert data['de']
  end

  define_method "test: does not export empty hashes" do
    Cldr::Export.export(:locales => %w(ar_AE), :components => %w(calendars))
    assert !File.exists?(Cldr::Export.path('ar_AE', 'calendars', 'yml'))
  end

  define_method "test: writes dot-separated symbols to yaml" do
    data = { :format  => { :narrow => :"calendars.gregorian.months.stand-alone.narrow" } }
    yaml = %(\nformat: \n  narrow: :"calendars.gregorian.months.stand-alone.narrow")

    assert_equal yaml, Cldr::Export::Yaml.new.emit(data.deep_stringify_keys)
  end

  Cldr::Data.locales.each do |locale|
    Cldr::Data.components.each do |component|
      define_method "test: exported yaml file yaml for #{locale}/#{component} readable" do
        Cldr::Export.export(:locales => [locale], :components => [component])
        assert_nothing_raised do
          YAML.load(File.open(Cldr::Data::Export.path(locale, component))) rescue Errno::ENOENT
        end
      end
    end
  end
end