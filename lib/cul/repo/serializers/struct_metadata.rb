module Cul::Repo::Serializers::StructMetadata 
  def self.serialize(k, v, out, opts={})
    i = ''
    indent = opts.fetch(:indent,0)
    indent.times { i << ' '}
    if v.is_a? Hash
      if k.nil?
        out.print i + "<mets:structMap TYPE=\"#{opts.fetch(:type,'physical')}\" LABEL=\"Device\" xmlns:mets=\"http://www.loc.gov/METS/\">\n"
      else
        out.print i + "<mets:div LABEL=\"#{k}\">\n"
      end
      v_opts = opts.merge(indent:indent+2)
      v.each {|key,value| serialize(key, value,out,v_opts)}
      out.print i + (k.nil? ? "</mets:structMap>\n"  : "</mets:div>\n")
    else
      out.print i + "<mets:div LABEL=\"#{k.to_s}\" CONTENTIDS=\"#{v}\" />\n"
    end
  end
  def serialize(k, v, out, opts={})
    Cul::Repo::Serializers::StructMetadata.serialize(k, v, out, opts)
  end
end