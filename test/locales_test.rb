require "minitest/autorun"
require "yaml"

# Consistency checks for locales/*.yml — no app boot or Mongo needed.
class LocalesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  # Keys that are deliberately empty in the locale files.
  ALLOWED_EMPTY = ["gram.skupina.obr", "gram.skupina.iko", "admin.text1"].freeze

  # Dynamic key families built at runtime from data values; their literal
  # prefixes show up in the source scan but are not complete keys.
  DYNAMIC_PREFIXES = ["entry.dom", "entry.kat_"].freeze

  def self.locales
    @locales ||= Dir[File.join(ROOT, "locales", "*.yml")].sort.to_h do |f|
      data = YAML.load_file(f)
      [File.basename(f, ".yml"), flatten(data[data.keys.first])]
    end
  end

  def self.flatten(hash, prefix = "", out = {})
    hash.each do |k, v|
      key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      v.is_a?(Hash) ? flatten(v, key, out) : out[key] = v
    end
    out
  end

  def test_all_locales_have_the_same_keys
    locales = self.class.locales
    all_keys = locales.values.flat_map(&:keys).uniq
    locales.each do |lang, keys|
      missing = all_keys - keys.keys
      assert_empty missing, "#{lang}.yml is missing keys: #{missing.sort.join(", ")}"
    end
  end

  def test_no_unexpected_empty_values
    self.class.locales.each do |lang, keys|
      empty = keys.select { |k, v| v.nil? || v.to_s.strip.empty? }.keys - ALLOWED_EMPTY
      assert_empty empty, "#{lang}.yml has empty values for: #{empty.sort.join(", ")}"
    end
  end

  def test_translation_keys_used_in_code_are_defined
    cs = self.class.locales.fetch("cs")
    sources = Dir[File.join(ROOT, "{views,lib}", "**", "*.{slim,rb}")] + [File.join(ROOT, "czjapp.rb")]
    used = sources.flat_map do |f|
      File.read(f, encoding: "utf-8").scan(/\bt\(\s*(['"])([a-z0-9_.;-]+)\1\s*[),]/i).map { |_, key| key }
    end.uniq - DYNAMIC_PREFIXES
    undefined = used.reject { |k| cs.key?(k) }
    assert_empty undefined, "keys used in code but missing from cs.yml: #{undefined.sort.join(", ")}"
  end
end
