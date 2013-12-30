require 'ostruct'

# referer parser output
class Fluent::RefererParserOutput < Fluent::Output
  Fluent::Plugin.register_output('referer_parser', self)

  config_param :tag,           :string, default: nil
  config_param :remove_prefix, :string, default: nil
  config_param :add_prefix,    :string, default: nil

  config_param :key_name, :string

  config_param :merge_referer_info,  :bool,   default: false
  config_param :out_key_known,       :string, default: 'referer_known'
  config_param :out_key_referer,     :string, default: 'referer_referer'
  config_param :out_key_search_term, :string, default: 'referer_search_term'

  UNKOWWN_STRING = 'UNKNOWN'
  PARSE_ERROR_STRUCT = OpenStruct.new(known: false)

  def initialize
    super
    require 'referer-parser'
  end

  def configure(conf)
    super

    if !@tag && !@remove_prefix && !@add_prefix
      fail Fluent::ConfigError, 'missing both of remove_prefix and add_prefix'
    end
    if @tag && (@remove_prefix || @add_prefix)
      fail Fluent::ConfigError, 'both of tag and remove_prefix/add_prefix must not be specified'
    end
    if @remove_prefix
      @removed_prefix_string = @remove_prefix + '.'
      @removed_length = @removed_prefix_string.length
    end
    @added_prefix_string = @add_prefix + '.' if @add_prefix
  end

  def tag_mangle(tag)
    if @tag
      @tag
    else
      if @remove_prefix &&
          ( (tag.start_with?(@removed_prefix_string) && tag.length > @removed_length) || tag == @remove_prefix)
        tag = tag[@removed_length..-1]
      end
      if @add_prefix
        tag = if tag && tag.length > 0
                @added_prefix_string + tag
              else
                @add_prefix
              end
      end
      tag
    end
  end

  def emit(tag, es, chain)
    tag = tag_mangle(tag)
    es.each do |time, record|
      parsed =
        begin
          RefererParser::Referer.new(record[@key_name])
        rescue
          PARSE_ERROR_STRUCT
        end
      record.merge!(
        @out_key_known       => parsed.known,
        @out_key_referer     => parsed.referer     || UNKOWWN_STRING,
        @out_key_search_term => parsed.search_term || UNKOWWN_STRING,
      )
      Fluent::Engine.emit(tag, time, record)
    end
    chain.next
  end
end
