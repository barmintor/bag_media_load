module Bag
  module DcHelpers
    def set_dc_extent(val)
      self.dc.update_indexed_attributes([:format=>0]=>val)
      self.dc.dirty = true
    end
    def set_dc_format(val)
      self.dc.update_indexed_attributes([:format=>0]=>val)
      self.dc.dirty = true
    end
    def set_dc_identifier(val)
      unless self.dc.term_values(:identifier).include? val
        self.dc.update_indexed_attributes([:identifier=>-1]=>val)
        self.dc.dirty = true
      end
    end
    def set_dc_source(val)
      self.dc.update_indexed_attributes([:source=>0]=>val)
      self.dc.dirty = true
      end
    end
    def set_dc_title(val)
      self.dc.update_indexed_attributes([:title=>0]=>val)
      self.dc.dirty = true
    end
    def set_dc_type(val)
      self.dc.update_indexed_attributes([:dc_type=>0]=>val)
      self.dc.dirty = true
    end
  end
end