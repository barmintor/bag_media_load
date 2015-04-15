require 'nokogiri'
module Arxv
  class AmdSec
    METS_NS = {
      mets: "http://www.loc.gov/METS/",
      premis: "info:lc/xmlns/premis-v2",
      fits: "http://hul.harvard.edu/ois/xml/ns/fits/fits_output",
      xlink: "http://www.w3.org/1999/xlink",
      xsi: "http://www.w3.org/2001/XMLSchema-instance",
      pronom:"http://www.nationalarchives.gov.uk/pronom/FileCollection"
    }
    def initialize(node)
      @node = node
      if @node
        mime = @node.xpath(".//premis:objectCharacteristicsExtension/fits:fits/fits:identification/fits:identity", METS_NS).first
        if mime
          @mime = mime['mimetype']
        end
        puid = @node.xpath(".//pronom:IdentificationFile/pronom:FileFormatHit/pronom:PUID", METS_NS).first
        if puid
          puid = puid.text
          if puid == 'fmt/111'
            magic = @node.xpath(".//HEADER/MAGICNUMBER", METS_NS).first
            if magic
              magic = magic.text
              magic_h = magic.to_i(16)
              if magic_h == 0xA5DC
                puid = 'fmt/39'
              elsif magic_h == 0xA5EC
                puid = 'fmt/40'
              elsif magic_h == 0x809
                product = @node.xpath(".//HEADER/PRODUCTVERSION", METS_NS).first.text
                product_h = product.to_i(16)
                if product_h == 0x500
                  puid = 'fmt/59'
                elsif product_h == 0x600
                  puid = 'fmt/61'
                end
              end
            end
          elsif puid == 'fmt/189'
            path = @node.xpath(".//premis:objectCharacteristicsExtension/fits:fits/fits:fileinfo/fits:filepath", METS_NS).first.text
            ext = File.extname(path)
            if ext == '.docx'
              puid = 'fmt/412'
            elsif ext == '.xlsx'
              puid = 'fmt/214'
            elsif ext == '.pptx'
              puid = 'fmt/215'
            end              
          end
          @puid = puid
        end
      end
    end
    def mime_type
      @mime
    end
    def puid
      @puid
    end
    def original_path
      @node.xpath(".//premis:originalName", METS_NS).text
    end
  end
end
