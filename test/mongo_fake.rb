require "json"

# Minimal in-memory stand-in for the Mongo client, backed by JSON fixtures
# in test/fixtures/. Supports the query shapes the display code uses:
# equality (incl. dotted paths and array membership), $exists, $ne, $in,
# $and, $or, the :sort find option and skip/limit. Anything else raises so
# a test fails loudly instead of silently returning wrong data.
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

  # replace a collection's docs for a single test (fixtures with values
  # relative to Date.today can't live in static JSON files)
  def load(name, docs)
    @collections[name.to_s] = FakeCollection.new(docs)
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

  # Read-side subset of the aggregation pipeline: $match, $group (hash _id of
  # '$field' refs, $sum accumulator), $sort (single key), $limit. Anything
  # richer raises, same philosophy as the query operators.
  def aggregate(pipeline, _opts = {})
    docs = @docs.map { |d| Marshal.load(Marshal.dump(d)) }
    pipeline.each do |stage|
      op, spec = stage.first
      case op.to_s
      when "$match"
        docs = docs.select { |doc| FakeMongoQuery.match?(doc, spec) }
      when "$group"
        docs = FakeMongoQuery.group(docs, spec)
      when "$sort"
        key, dir = spec.first
        docs = docs.sort_by { |doc| doc[key.to_s] || 0 }
        docs.reverse! if dir.to_i < 0
      when "$limit"
        docs = docs.take(spec.to_i)
      else
        raise NotImplementedError, "FakeMongo: aggregation stage #{op} not supported"
      end
    end
    docs
  end
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
      case key.to_s
      when "$and" then cond.all? { |sub| match?(doc, sub) }
      when "$or" then cond.any? { |sub| match?(doc, sub) }
      else match_key?(doc, key.to_s, cond)
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
        when "$gte" then !value.nil? && value >= opval
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

  # $group with _id as a hash of '$field' refs and {'$sum' => '$field'|1}
  # accumulators — the shape CzjUsageStat uses.
  def group(docs, spec)
    accs = spec.reject { |k, _| k.to_s == "_id" }
    docs.group_by { |doc| resolve_refs(spec["_id"], doc) }.map do |id, group_docs|
      row = {"_id" => id}
      accs.each do |name, acc|
        op, ref = acc.first
        raise NotImplementedError, "FakeMongo: accumulator #{op} not supported" unless op.to_s == "$sum"
        row[name.to_s] = group_docs.sum { |d| ref.is_a?(String) ? resolve_refs(ref, d).to_i : ref.to_i }
      end
      row
    end
  end

  def resolve_refs(spec, doc)
    case spec
    when Hash then spec.transform_values { |v| resolve_refs(v, doc) }
    when /\A\$/ then dig_path(doc, spec[1..])
    else spec
    end
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
