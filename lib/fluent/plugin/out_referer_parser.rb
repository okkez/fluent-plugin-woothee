# referer parser output
class Fluent::RefererParserOutput < Fluent::Output
  Fluent::Plugin.register_output('referer_parser', self)

  config_param :tag,           :string, default: nil
  config_param :remove_prefix, :string, default: nil
  config_param :add_prefix,    :string, default: nil

  config_param :key_name,       :string
  config_param :referers_yaml,  :string, default: nil
  config_param :encodings_yaml, :string, default: nil

  config_param :out_key_known,       :string, default: 'referer_known'
  config_param :out_key_referer,     :string, default: 'referer_referer'
  config_param :out_key_host,        :string, default: 'referer_host'
  config_param :out_key_search_term, :string, default: 'referer_search_term'

  def initialize
    super
    require 'cgi'
    require 'yaml'
    require 'referer-parser'
  end

  def configure(conf)
    super

    @referer_parser = RefererParser::Referer.new('http://example.org/', @referers_yaml)

    if @encodings_yaml
      @encodings = YAML.load_file(@encodings_yaml)
    else
      @encodings = {}
    end

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
      is_valid = true
      begin
        @referer_parser.parse(record[@key_name])
      rescue
        is_valid = false
      end
      if is_valid && @referer_parser.known?
        search_term = @referer_parser.search_term
        host = @referer_parser.uri.host
        parameters = CGI.parse(@referer_parser.uri.query)
        input_encoding = @encodings[host] || parameters['ie'][0] || parameters['ei'][0]
        begin
          search_term = search_term.force_encoding(input_encoding).encode('utf-8') if input_encoding && /\Autf-?8\z/i !~ input_encoding
        rescue
          $log.error('invalid referer: ' + @referer_parser.uri.to_s)
        end
        record.merge!(
          @out_key_known       => true,
          @out_key_referer     => @referer_parser.referer,
          @out_key_host        => host,
          @out_key_search_term => search_term
        )
      else
        record.merge!(@out_key_known => false)
      end
      Fluent::Engine.emit(tag, time, record)
    end
    chain.next
  end
end
