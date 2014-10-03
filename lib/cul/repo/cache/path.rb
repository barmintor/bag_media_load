module Cul::Repo::Cache
class Path
	def self.factory(opts = nil)
    opts ||= APP_CONFIG
    unless opts[:cache_directory]
    	# warn about missing config
      return @path
    end
    unless @path
      @path = self.new(opts)
    else
      @path.send :initialize, opts
    end
    @path
  end

  def self.path_for(opts={})
    factory.for(opts)
  end

  def self.exists_for?(opts={})
    if opts.is_a? String
      File.exists? opts
    else
      File.exists? path_for(opts)
    end
  end

  def path_for_id(id)
    digest = Digest::SHA256.hexdigest(id)
    File.join(@cache_path, digest[0..1], digest[2..3], digest[4..5], digest)
  end

	def initialize(opts)
		@cache_path = opts[:cache_directory]
	end

	def for(opts={})
		return nil if !opts[:id] or !opts[:type] or !opts[:format]

		path = path_for_id(opts[:id])
		if opts[:type] == Cul::Repo::Cache::DerivativeInfo::TYPE_ZOOM
      # The size param is ignored for jp2 files because they're always the same size as the original image.
      path = File.join(path, "#{opts[:type].to_s}.#{opts[:format]}")
		else
			return nil if !opts[:size]

			if opts[:type]
				path = File.join(path, opts[:type].to_s)
				if opts[:size]
					if opts[:format] # no defaults?
						path = File.join(path, "#{opts[:size]}.#{opts[:format]}")
					else
						path = File.join(path, "#{opts[:size]}.jpg")
					end
				end
			end
		end
		path
	end
end
end
