require "minitest/autorun"
require_relative "../lib/czj_fuzzy_match"

# Pure-data tests for the translatelist fuzzy matching (no Mongo needed).
class FuzzyMatchTest < Minitest::Test
  def test_find_closest_match_picks_nearest
    match = CzjFuzzyMatch.find_closest_match("kocka", ["kocour", "kockaa", "pes"], 2)
    assert_equal "kockaa", match
  end

  def test_find_closest_match_nil_beyond_max_distance
    assert_nil CzjFuzzyMatch.find_closest_match("kocka", ["slon", "zirafa"], 2)
  end

  def test_single_word_first_try_match
    m = CzjFuzzyMatch.single_word_match(+"kocke", ["kocka"], "en")
    assert_equal "kocka", m["match"]
    assert_equal true, m["resultinfo1"]
    assert_equal false, m["resultinfo2"]
  end

  def test_single_word_match_after_truncation
    # no match at full length, then slice!(-2,2) shortens until "kocka" is close
    m = CzjFuzzyMatch.single_word_match(+"kockaxxxx", ["kocka"], "en")
    assert_equal "kocka", m["match"]
    assert_equal false, m["resultinfo1"]
    assert_equal true, m["resultinfo2"]
  end

  def test_ne_prefix_stripped_for_czech_only
    cs = +"neplavat"
    CzjFuzzyMatch.single_word_match(cs, ["plavat"], "cs")
    assert_equal "plavat", cs, "cs search should be mutated by ne-strip"

    en = +"neplavat"
    CzjFuzzyMatch.single_word_match(en, ["plavat"], "en")
    assert_equal "neplavat", en, "en search must not be ne-stripped"
  end

  def test_long_word_halving_path
    m = CzjFuzzyMatch.single_word_match(+"abcdefghijklmnopqrst", ["abcdefghij"], "en")
    assert_equal "abcdefghij", m["match"]
    assert_equal true, m["resultinfo2"]
  end

  def test_single_word_no_match_returns_nil_match
    m = CzjFuzzyMatch.single_word_match(+"xyzxyz", ["dlouheslovo"], "en")
    assert_nil m["match"]
    assert_equal false, m["resultinfo1"]
    assert_equal false, m["resultinfo2"]
  end

  def test_multisyllabic_skips_short_first_word_and_matches
    m = CzjFuzzyMatch.multisyllabic_match(["ve", "skole", "dnes"], ["skola"])
    assert_equal "skola", m["match"]
    assert_equal true, m["resultinfo3"]
  end

  def test_multisyllabic_no_match
    m = CzjFuzzyMatch.multisyllabic_match(["neco", "jineho"], ["slovnik"])
    assert_nil m["match"]
    assert_equal false, m["resultinfo3"]
  end
end
