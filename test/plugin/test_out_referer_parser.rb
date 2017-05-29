require 'helper'

# RefererParserOutput test
class Fluent::RefererParserOutputTest < Test::Unit::TestCase
  # through & merge
  CONFIG1 = %(
type referer_parser
key_name referer
remove_prefix test
add_prefix merged
)

  CONFIG2 = %(
type referer_parser
key_name ref
remove_prefix test
add_prefix merged
out_key_known        ref_known
out_key_referer      ref_referer
out_key_host         ref_host
out_key_search_term  ref_search_term
)

  CONFIG3 = %(
type referer_parser
key_name ref
remove_prefix test
add_prefix merged
referers_yaml test/data/referers.yaml
encodings_yaml test/data/encodings.yaml
)

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf = CONFIG1, tag = 'test')
    Fluent::Test::OutputTestDriver.new(Fluent::RefererParserOutput, tag).configure(conf)
  end

  def test_configure
    # through & merge
    d = create_driver CONFIG1
    assert_equal 'referer', d.instance.key_name
    assert_equal 'test',    d.instance.remove_prefix
    assert_equal 'merged',  d.instance.add_prefix

    assert_equal 'referer_known',       d.instance.out_key_known
    assert_equal 'referer_referer',     d.instance.out_key_referer
    assert_equal 'referer_search_term', d.instance.out_key_search_term

    # filter & merge
    d = create_driver CONFIG2
    assert_equal 'ref',    d.instance.key_name
    assert_equal 'test',   d.instance.remove_prefix
    assert_equal 'merged', d.instance.add_prefix

    assert_equal 'ref_known',       d.instance.out_key_known
    assert_equal 'ref_referer',     d.instance.out_key_referer
    assert_equal 'ref_search_term', d.instance.out_key_search_term
  end

  def test_tag_mangle
    p = create_driver(CONFIG1).instance
    assert_equal 'merged.data', p.tag_mangle('data')
    assert_equal 'merged.data', p.tag_mangle('test.data')
    assert_equal 'merged.test.data', p.tag_mangle('test.test.data')
    assert_equal 'merged', p.tag_mangle('test')
  end

  def test_emit1
    d = create_driver(CONFIG1, 'test.message')
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run do
      d.emit({ 'value' => 0 }, time)
      d.emit({ 'value' => 1, 'referer' => 'http://www.google.com/search?q=gateway+oracle+cards+denise+linn&hl=en&client=safari' }, time)
      d.emit({ 'value' => 2, 'referer' => 'http://www.unixuser.org/' }, time)
      d.emit({ 'value' => 3, 'referer' => 'http://www.google.co.jp/search?hl=ja&ie=Shift_JIS&c2coff=1&q=%83%7D%83%8B%83%60%83L%83%83%83X%83g%81@%8Aw%8Em%98_%95%B6&lr=' }, time)
      d.emit({ 'value' => 4, 'referer' => 'http://www.google.co.jp/search?hl=ja&ie=Shift_J&c2coff=1&q=%83%7D%83%8B%83%60%83L%83%83%83X%83g%81@%8Aw%8Em%98_%95%B6&lr=' }, time)
      d.emit({ 'value' => 5, 'referer' => 'http://search.yahoo.co.jp/search?p=%E3%81%BB%E3%81%92&aq=-1&oq=&ei=UTF-8&fr=sfp_as&x=wrt' }, time)
    end

    emits = d.emits
    assert_equal 6,                emits.size
    assert_equal 'merged.message', emits[0][0]
    assert_equal time,             emits[0][1]

    m = emits[0][2]
    assert_equal 0,         m['value']
    assert_equal false,     m['referer_known']
    assert_nil m['referer_referer']
    assert_nil m['referer_search_term']
    assert_equal 2,         m.keys.size

    m = emits[1][2]
    assert_equal 1,                                  m['value']
    assert_equal true,                               m['referer_known']
    assert_equal 'Google',                           m['referer_referer']
    assert_equal 'www.google.com',                   m['referer_host']
    assert_equal 'gateway oracle cards denise linn', m['referer_search_term']
    assert_equal 6,         m.keys.size

    m = emits[2][2]
    assert_equal 2,         m['value']
    assert_equal false,     m['referer_known']
    assert_nil m['referer_referer']
    assert_nil m['referer_search_term']
    assert_equal 3,         m.keys.size

    m = emits[3][2]
    assert_equal 3,                          m['value']
    assert_equal true,                       m['referer_known']
    assert_equal 'Google',                   m['referer_referer']
    assert_equal 'www.google.co.jp',         m['referer_host']
    assert_equal 'マルチキャスト　学士論文', m['referer_search_term']
    assert_equal 6,         m.keys.size

    # invalid input_encoding
    m = emits[4][2]
    assert_equal 4,        m['value']
    assert_equal true,     m['referer_known']
    assert_equal 'Google', m['referer_referer']
    assert_equal 'www.google.co.jp',         m['referer_host']
    assert_equal 6,        m.keys.size

    m = emits[5][2]
    assert_equal 5,                    m['value']
    assert_equal true,                 m['referer_known']
    assert_equal 'Yahoo!',             m['referer_referer']
    assert_equal 'search.yahoo.co.jp', m['referer_host']
    assert_equal 'ほげ',               m['referer_search_term']
    assert_equal 6,                    m.keys.size
  end

  def test_emit2
    d = create_driver(CONFIG2, 'test.message')
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run do
      d.emit({ 'value' => 0 }, time)
      d.emit({ 'value' => 1, 'ref' => 'http://www.google.com/search?q=gateway+oracle+cards+denise+linn&hl=en&client=safari' }, time)
      d.emit({ 'value' => 2, 'ref' => 'http://www.unixuser.org/' }, time)
      d.emit({ 'value' => 3, 'ref' => 'https://www.google.com/search?q=%E3%81%BB%E3%81%92&ie=utf-8&oe=utf-8' }, time)
    end

    emits = d.emits
    assert_equal 4,                emits.size
    assert_equal 'merged.message', emits[0][0]
    assert_equal time,             emits[0][1]

    m = emits[0][2]
    assert_equal 0,         m['value']
    assert_equal false,     m['ref_known']
    assert_nil m['ref_referer']
    assert_nil m['ref_search_term']
    assert_equal 2,         m.keys.size

    m = emits[1][2]
    assert_equal 1,                                  m['value']
    assert_equal true,                               m['ref_known']
    assert_equal 'Google',                           m['ref_referer']
    assert_equal 'www.google.com',                   m['ref_host']
    assert_equal 'gateway oracle cards denise linn', m['ref_search_term']
    assert_equal 6,         m.keys.size

    m = emits[2][2]
    assert_equal 2,         m['value']
    assert_equal false,     m['ref_known']
    assert_nil m['ref_referer']
    assert_nil m['ref_host']
    assert_nil m['ref_search_term']

    m = emits[3][2]
    assert_equal 3,                m['value']
    assert_equal true,             m['ref_known']
    assert_equal 'Google',         m['ref_referer']
    assert_equal 'www.google.com', m['ref_host']
    assert_equal 'ほげ',           m['ref_search_term']
  end

  def test_emit3
    d = create_driver(CONFIG3, 'test.message')
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run do
      d.emit({ 'value' => 0 }, time)
      d.emit({ 'value' => 1, 'ref' => 'http://ezsch.ezweb.ne.jp/search/?sr=0101&query=aiueo%20%95a%93I' }, time)
      d.emit({ 'value' => 2, 'ref' => 'http://ezsch.ezweb.ne.jp/search/ezGoogleMain.php?query=%83%8D' }, time)
      d.emit({ 'value' => 3, 'ref' => 'http://www.google.co.jp/search?hl=ja&ie=Shift_JIS&c2coff=1&q=%83%7D%83%8B%83%60%83L%83%83%83X%83g%81@%8Aw%8Em%98_%95%B6&lr=' }, time)
    end

    emits = d.emits
    assert_equal 4,                emits.size
    assert_equal 'merged.message', emits[0][0]
    assert_equal time,             emits[0][1]

    m = emits[0][2]
    assert_equal 0,     m['value']
    assert_equal false, m['referer_known']
    assert_nil m['referer_referer']
    assert_nil m['referer_search_term']
    assert_equal 2,     m.keys.size

    m = emits[1][2]
    assert_equal 1,                   m['value']
    assert_equal true,                m['referer_known']
    assert_equal 'Ezweb',             m['referer_referer']
    assert_equal 'ezsch.ezweb.ne.jp', m['referer_host']
    assert_equal 'aiueo 病的',        m['referer_search_term']
    assert_equal 6,                   m.keys.size

    m = emits[2][2]
    assert_equal 2,                   m['value']
    assert_equal true,                m['referer_known']
    assert_equal 'Ezweb',             m['referer_referer']
    assert_equal 'ezsch.ezweb.ne.jp', m['referer_host']
    assert_equal 'ロ',                m['referer_search_term']
    assert_equal 6,                   m.keys.size

    m = emits[3][2]
    assert_equal 3,                          m['value']
    assert_equal true,                       m['referer_known']
    assert_equal 'Google',                   m['referer_referer']
    assert_equal 'www.google.co.jp',         m['referer_host']
    assert_equal 'マルチキャスト　学士論文', m['referer_search_term']
    assert_equal 6,         m.keys.size
  end
end
