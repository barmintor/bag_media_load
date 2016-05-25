module BagIt
  module DcHelpers
    def dc_dirty!
      self.datastreams['DC'].changed_attributes[:content] = true
    end
    def set_dc_contributor(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_contributor=>0]=>val)
      self.dc_dirty!
    end
    def set_dc_extent(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_extent=>0]=>val)
      self.dc_dirty!
    end
    def set_dc_format(val)
      self.datastreams['DC'].update_indexed_attributes([:dc_format=>0]=>val)
      self.dc_dirty!
    end
    def add_dc_identifier(val)
      unless self.datastreams['DC'].term_values(:dc_identifier).include? val
        self.datastreams['DC'].update_indexed_attributes([:dc_identifier=>-1]=>val)
        self.dc_dirty!
      end
    end
    def set_dc_identifier(val)
        self.datastreams['DC'].update_indexed_attributes([:dc_identifier]=>[val])
        self.dc_dirty!
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
    def collapse_ids
      dc = datastreams["DC"]
      ids = dc.term_values(:dc_identifier)
      new_ids = ids.uniq
      return if new_ids.sort.eql? ids.sort
      self.set_dc_identifier(self.pid)
      new_ids.each {|idval| self.add_dc_identifier(idval) if idval != self.pid}
      dc.content_will_change!
    end
  end
end
