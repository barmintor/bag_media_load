# encoding: UTF-8
module BagIt
  module PairTree
    def self.path(id, separator=nil)
      id = id.clone
      separator = (separator and separator.length > 0) ? separator.clone : '/'
      id.gsub!(/[\"*+,<=>?\\^|]|[^\x21-\x7e]/, &method(:utf8_bytes_to_hex_encoded))
      id.gsub!(/\//, '=')
      id.gsub!(/:/, '+')
      id.gsub!(/\./, ',')
      path = separator.clone
      until (id.nil? or id.eql? '') do
        path.concat(id[0...2]).concat(separator)
        id = id.slice!(2..-1)
      end
      path
    end

    def self.id(path, separator = nil)
      path = path.clone
      separator = (separator and separator.length > 0) ? separator.clone : '/'
      parts = path.strip.split separator
      id = ''
      parts.each do |part|
        if part.length == 2
          id << part
        elsif part.length == 1
          id << part
          break
        else
          break if id.length > 0  
        end
      end
      id.gsub!(/[=]/, '/')
      id.gsub!(/\+/, ':')
      id.gsub!(/,/, '.')
      id.gsub!(/(\^..)+/, &method(:hex_encoded_to_decoded_string))
      id
    end

    private
    def self.string_to_utf8_bytes(str)
      str = str.gsub(/\r\n/, "\n");
      out = []

      str.each_codepoint do |c|
        if c < 128
          out << c 
        elsif c < 2048 # 11-bit number
          out << ((c >> 6) | 192)
          out << ((c & 63) | 128)
        else
          out << ((c >> 12) | 224)

          out << (((c >> 6) & 63) | 128)
          out << ((c & 63) | 128)
        end
      end
      out
    end

    def self.utf8_bytes_to_hex_encoded(input)
      he = ''
      input = string_to_utf8_bytes(input)
      input.each do |c|
        he << '^' << c.to_s(16)
      end
      he
    end

    def self.hex_encoded_to_utf8_bytes(input)
    end

    def self.hex_encoded_to_decoded_string(match)
      r = ''
      bytes = match[1..-1].split('^').collect {|h| h.to_i(16)}
      bytes.reverse!
      while (bytes.length > 0) do
        b0 = bytes.pop
        if b0 < 128
          r << b0
        elsif (b0 > 191 and b0 < 224) # two byte  (11 bit) sequence
          ch = (((b0 & 31) << 6) | (bytes.pop & 63))
          r << ch
        else
          ch = (((b0 & 15) << 12) | ((bytes.pop & 63) << 6) | (bytes.pop & 63))
          r << ch
        end
      end
      return r
    end
  end
end