module BagIt
  module DcHelpers
    def dc_dirty!
      self.datastreams['DC'].changed_attributes[:content] = true
    end
    def set_dc_extent(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_extent=>0]=>val)
      self.dc_dirty!
    end
    def set_dc_format(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_format=>0]=>val)
      self.dc_dirty!
    end
    def set_dc_identifier(val)
      unless self.datastreams['DC'].term_values(:dc_identifier).include? val
        self.datastreams['DC'].update_indexed_attributes([:dc_identifier=>-1]=>val)
        self.dc_dirty!
      end
    end
    def set_dc_source(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_source=>0]=>val)
      self.dc_dirty!
    end
    def set_dc_title(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_title=>0]=>val)
      self.dc_dirty!
    end
    def set_dc_type(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_type=>0]=>val)
      self.dc_dirty!
    end
  end
end
