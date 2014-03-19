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
        pattern = v["pattern"]
        subs = Array(v["subs"] || ['${0}']) # default to the match pattern
        output = v['output'] || '%s' # default to whatver the match was
        @blocks[key] = NameParser.regex_proc(pattern, subs, output, &@blocks[source])
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

    def verso(input)
      if @blocks[:verso]
        _r = @blocks[:verso].yield input
        if _r
          true
        else
          false
        end
      end
    end

    def self.regex_proc(pattern=nil, subs, output, &src)
      pattern ||= '.*'
      regex = Regexp.new(pattern)
      Proc.new do |input|
         match = regex.match(src.call(input))
         subst = substitutes(subs, match)
         output % subst
      end
    end

    def self.substitutes(inputs, matchdata)
      if matchdata
        subs = {}
        inputs.collect do |input|
          
          input.scan(/\$\{([^}]+)\}/).each {|s| subs[s[0]] = nil}
          if subs.length != 0
            # do substitutions
            subs.each_key do |patt|
              group = patt.split(':').first
              method = input.index(',').nil? ? nil : input.split(',')[1]
              _default = patt.index(':').nil? ? nil : patt.split(':')[1]
              #puts "patt: #{patt} group: #{group} method: #{method} default: #{_default}"
              if matchdata[group.to_i] and matchdata[group.to_i].length > 0
                input = matchdata[group.to_i]
              elsif _default
                input = _default
              end
              input = self.send(method.to_sym, input) if method
            end
          end
          input
        end
      else
        []
      end
    end

    def self.integer(string)
      string.to_i
    end

    def self.float(string)
      string.to_f
    end

    def self.complex(string)
      string.to_c
    end

    def self.boolean(string)
      string = string.strip
      string =~ /^true$/i or string =~ /^yes$/i or string =~ /^[YyTt]$/
    end

    class Default
      def initialize(project_id, opts={})
        @project_id = project_id
      end

      def id(input)
        id = ('apt://columbia.edu/' << @project_id << '/' << input)
        id.gsub(/\/+/,'/')
        id
      end

      def parent(input)
        nil
      end

      def side(input)
        nil
      end

      def verso(input)
        false
      end
    end

  end

end
