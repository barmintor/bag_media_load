APP_CONFIG = ActiveSupport::HashWithIndifferentAccess.new(YAML.load_file("#{Rails.root}/config/cache_config.yml")[Rails.env])
include Cul::Repo::Cache::DerivativeInfo
namespace :prime do
  task :bag => :environment do
    bag_path = ENV['BAG_PATH']
    alg = ENV['CHECKSUM_ALG'] || 'sha1'
    override = !!ENV['OVERRIDE'] and !(ENV['OVERRIDE'] =~ /^false$/i)
    upload_dir = ActiveFedora.config.credentials[:upload_dir]
    # parse bag-info for external-id and title
    bag_info = BagIt::Info.new(bag_path)
    raise "External-Identifier for bag is required" if bag_info.external_id.blank?
    manifest = File.join(bag_path, "manifest-#{alg}.txt")
    raise "Manifest #{manifest} does not exist" unless File.exists? manifest
    paths = []
    open(manifest) do |blob|
      blob.each do |line|
        line.strip!
        paths << line
      end
    end
    cache_paths = Cul::Repo::Cache::Path.factory(APP_CONFIG)
    paths.each do |path|
      gr_id = "apt://columbia.edu/#{bag_info.external_id}/#{path}"
      generic_resource = GenericResource.search_repo(identifier: gr_id).first
      if generic_resource
        conditions = {image_id: generic_resource.pid, format: 'png'}
        content_ds = generic_resource.datastreams['content']
        content_path = (content_ds.dsLocation =~ /^file:\//) ? content_ds.dsLocation.sub(/^file:/,'') : content_ds.dsLocation
        Imogen.with_image(content_path) do |img|

          scaled_cache_path = cache_paths.for({:id => generic_resource.pid, :size => LARGE_SCALED_SIZE, :format => APP_CONFIG[TYPE_SCALED]['base_format'], :type => TYPE_SCALED})
          square_cache_path = cache_paths.for({:id => generic_resource.pid, :size => LARGE_SQUARE_SIZE, :format => APP_CONFIG[TYPE_SQUARE]['base_format'], :type => TYPE_SQUARE})

          if override or !File.exists?(square_cache_path)
            logger.debug 'Creating base square image...'
            start_time = Time.now
            FileUtils.mkdir_p(File.dirname(square_cache_path))
            Imogen::AutoCrop.convert(img, square_cache_path, sizes['square'])
            logger.debug 'Created base square image in ' + (Time.now-start_time).to_s + ' seconds'
          end

          if override or !File.exists?(scaled_cache_path)
            logger.debug 'Creating base scaled image...'
            start_time = Time.now
            FileUtils.mkdir_p(File.dirname(scaled_cache_path))
            Imogen::Scaled.convert(img, scaled_cache_path, sizes['scaled'])
            logger.debug 'Created base scaled image in ' + (Time.now-start_time).to_s + ' seconds'
          end
        end
      end
    end
  end
end