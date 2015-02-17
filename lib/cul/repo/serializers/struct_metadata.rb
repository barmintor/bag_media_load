module Cul::Repo::Serializers::StructMetadata 
  def self.serialize(k, v, out, indent=0)
    i = ''
    indent.times { i << ' '}
    if v.is_a? Hash
      if k.nil?
        out.print i + "<mets:structMap TYPE=\"physical\" LABEL=\"Device\" xmlns:mets=\"http://www.loc.gov/METS/\">\n"
      else
        out.print i + "<mets:div LABEL=\"#{k}\">\n"
      end
      v.each {|key,value| serialize(key, value,out,indent+2)}
      out.print i + (k.nil? ? "</mets:structMap>\n"  : "</mets:div>\n")
    else
      out.print i + "<mets:div LABEL=\"#{k.to_s}\" CONTENTIDS=\"#{v}\" />\n"
    end
  end
  def serialize(k, v, out, indent=0)
    Cul::Repo::Serializers::StructMetadata.serialize(k, v, out, indent)
  end
end