module BagIt
	class NameParser

    def initialize(opts = {})
      @blocks = {}
      # returns the path listed in the manifest
      @blocks[:path] = Proc.new {|input| input}
      # returns the base file name of the path listed in the manifest
      @blocks[:basename] = Proc.new {|input| File.basename(input)}
      opts.each do |k, v|
        parts = k.to_s.split "_from_"
        key = parts[0].to_sym
        source = parts[1].to_sym
        pattern = v[0]
        subs = v[1]
        @blocks[key] = NameParser.regex_proc(pattern, subs, &@blocks[source])
      end
    end

    def id(input)
      @blocks[:id] ? (@blocks[:id].yield input) : input
    end

    def parent(input)
      @blocks[:parent] ? (@blocks[:parent].yield input) : nil
    end

    # expected to return 'R' or 'V'
    def side(input)
      if @blocks[:side]
        _r = @blocks[:side].yield input
        if _r and _r =~ /[vV]/
          'V'
        else
          'R'
        end
      else
        nil
      end
    end

    def self.regex_proc(pattern, substitution, &src)
      regex = Regexp.new(pattern)
      Proc.new do |input|
         match = regex.match(src.call(input))
         substitute(substitution, match)
      end
    end

    def self.substitute(input, matchdata)
      if matchdata[0]
        subs = {}
        input.scan(/\$\{([^}]+)\}/).each {|s| subs[s[0]] = nil}
        if subs.length != 0
          # do substitutions
          subs.each_key do |patt|
            _p = Regexp.new('\$\{' + Regexp.escape(patt.to_s) + '\}')
            _default = patt.index(':') ? patt.slice(patt.index(':') + 1..-1) : nil
            if matchdata[patt.to_i] and matchdata[patt.to_i].length > 0
              input = input.gsub(_p, matchdata[patt.to_i])
            elsif _default
              input = input.gsub(_p, _default)
            end
          end
        end
        input
      else
        nil
      end
    end
  end
end