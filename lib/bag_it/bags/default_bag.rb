module BagIt
module Bags
class DefaultBag
  def initialize(parent_agg, bag_dir)
    if parent_agg.is_a? ActiveFedora::Base
      @parent = parent_agg
    else
      @parent = nil
    end
    
    if File.basename(bag_dir) == 'bag-info.txt'
      @bag_path = File.dirname(bag_dir)
    else
      @bag_path = bag_dir
    end
    
    @bag_info = BagIt::Info.new(File.join(bag_path,'bag-info.txt'))
    if @bag_info.external_id.blank?
      @bag_info.external_id = bag_path.split('/')[-1]
    end

  end
  def load

  end
end
end
end