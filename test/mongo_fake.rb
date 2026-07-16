require "json"

# Minimal in-memory stand-in for the Mongo client, backed by JSON fixtures
# in test/fixtures/. Supports the query shapes the display code uses:
# equality (incl. dotted paths and array membership), $and, $exists, $ne,
# $in, and the :sort find option. Anything else raises so a test fails loudly
# instead of silently returning wrong data.
class FakeMongo
  FIXDIR = File.expand_path("fixtures", __dir__)

  def initialize
    @collections = Hash.new { |h, k| h[k] = FakeCollection.new([]) }
    Dir[File.join(FIXDIR, "*.json")].each do |file|
      name = File.basename(file, ".json")
      @collections[name] = FakeCollection.new(JSON.parse(File.read(file)))
    end
  end

  def [](name)
    @collections[name.to_s]
  end
end

class FakeCollection
  def initialize(docs)
    @docs = docs
  end

  def find(filter = {}, opts = {})
    result = @docs.select { |doc| FakeMongoQuery.match?(doc, filter) }
    if opts[:sort]
      key, dir = opts[:sort].first
      result = result.sort_by { |doc| FakeMongoQuery.dig_path(doc, key.to_s) || 0 }
      result.reverse! if dir.to_i < 0
    end
    FakeResult.new(result)
  end

  def insert_one(*)
    raise NotImplementedError, "FakeMongo is read-only"
  end
  alias_method :update_one, :insert_one
  alias_method :update_many, :insert_one
  alias_method :delete_one, :insert_one
  alias_method :delete_many, :insert_one
  alias_method :aggregate, :insert_one
end

class FakeResult
  include Enumerable

  def initialize(docs)
    @docs = docs
  end

  # Deep-copy so callers mutating a result never corrupt the fixtures.
  def each(&block)
    @docs.map { |d| Marshal.load(Marshal.dump(d)) }.each(&block)
  end

  def first
    Marshal.load(Marshal.dump(@docs.first)) unless @docs.empty?
  end

  def skip(n)
    FakeResult.new(@docs.drop(n.to_i))
  end

  def limit(n)
    FakeResult.new(@docs.take(n.to_i))
  end

  def count_documents
    @docs.size
  end
  alias_method :count, :count_documents
end

module FakeMongoQuery
  module_function

  def match?(doc, filter)
    filter.all? do |key, cond|
      if key.to_s == "$and"
        cond.all? { |sub| match?(doc, sub) }
      else
        match_key?(doc, key.to_s, cond)
      end
    end
  end

  def match_key?(doc, path, cond)
    value = dig_path(doc, path)
    case cond
    when Hash
      cond.all? do |op, opval|
        case op.to_s
        when "$exists" then opval ? !value.nil? : value.nil?
        when "$ne" then !compare(value, opval)
        when "$in" then opval.any? { |v| compare(value, v) }
        else raise NotImplementedError, "FakeMongo: operator #{op} not supported"
        end
      end
    else
      compare(value, cond)
    end
  end

  # Mongo equality also matches when the stored value is an array
  # containing the operand.
  def compare(value, operand)
    (value.is_a?(Array) && !operand.is_a?(Array)) ? value.include?(operand) : value == operand
  end

  def dig_path(doc, path)
    path.split(".").reduce(doc) do |cur, part|
      case cur
      when Hash then cur[part]
      when Array
        if /\A\d+\z/.match?(part)
          cur[part.to_i]
        else
          cur.filter_map { |el| el[part] if el.is_a?(Hash) }.flatten(1)
        end
      end
    end
  end
end
