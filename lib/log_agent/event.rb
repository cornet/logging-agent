require 'uuid'
require 'socket'

module LogAgent
  class Event
    include LogAgent::LogHelper
    
    attr_reader :source_type, :source_host, :source_path, :uuid
    attr_accessor :tags, :fields
    attr_accessor :type, :message, :message_format, :timestamp

    def initialize opts={}
      @uuid = opts[:uuid] || UUID.generate
      @type = opts[:type] || ""
      @source_type = opts[:source_type] || ""
      @source_host = opts[:source_host] || Socket.gethostname 
      @source_path = opts[:source_path] || ""
      @tags = opts[:tags] || []
      @message = opts[:message] || ""
      @message_format = opts[:message_format] || nil
      @timestamp = opts[:timestamp] || Time.now
      @fields = opts[:fields] || {}
      debug "Event '#{@uuid}' created"
    end
    
    def message_format= new_format
      @message_format = new_format
    end
    
    def message
      if @message_format
        @message_format.dup.tap do |message|
          message.gsub!('%{@timestamp}') { self.timestamp.iso8601(6) }
          @fields.each_pair do |key, value|
            message.gsub! "%{#{key}}", value.to_s
          end
          message.gsub!(/%{@tags:?(.*)}/) { |m| m =~ /%{@tags(:?)(.*)}/ && self.tags.join($1==":" ? $2 : " ") }
          message.gsub!('%{@source_type}', self.source_type)
          message.gsub!('%{@source_host}', self.source_host)
          message.gsub!('%{@source_path}', self.source_path)
          message.gsub!('%{@type}', self.type)
          message.gsub!('%{@uuid}', self.uuid)
        end
      else
        @message
      end
    end
    
    def message= new_message
      raise RuntimeError, "message is immutable when message_format is set" if @message_format
      @message = new_message
    end
    
    def to_payload
      debug "Dumping event '#{@uuid}' to payload:"
      JSON.dump({
        '@timestamp'    => self.timestamp.iso8601(6),
        '@source_type'  => self.source_type,
        '@source_host'  => self.source_host,
        '@source_path'  => self.source_path,
        '@fields'       => self.fields,
        '@message'      => self.message,
        '@tags'         => self.tags,
        '@type'         => self.type, 
        '@uuid'         => self.uuid
      }).tap { |json| debug json }
    end
    
    def self.from_payload(json)
      data = JSON.load(json)
      new({
        :timestamp    => Time.parse(data['@timestamp']),
        :source_host  => data['@source_host'],
        :source_path  => data['@source_path'],
        :source_type  => data['@source_type'],
        :fields       => data['@fields'],
        :message      => data['@message'],
        :tags         => data['@tags'],
        :type         => data['@type'],
        :uuid         => data['@uuid']
      }).tap { |event| LogAgent.logger.debug "[Event] Loaded event '#{event.uuid}' object from json: #{json}" }
    end
  end
end