require 'open-uri'
require 'rdf'
require 'rdf/turtle'
module Pronom
	# POST a Sparql query as the 'query' param to this endpoint
    SPARQL = 'http://test.linkeddatapronom.nationalarchives.gov.uk/sparql/endpoint.php'
	QBASE = 'http://test.linkeddatapronom.nationalarchives.gov.uk/doc/file-format/%s.ttl'
	UK_REF = RDF::URI('http://reference.data.gov.uk/')
	IDS = UK_REF + 'id/'
	FORMAT_ID = IDS + 'file-format/'
	TR = UK_REF + 'technical-registry/'
	CHAR_ENCODING = TR + 'character-encoding'
	COMPRESSION_TYPE = TR + 'compression-type'
	MIME = TR + 'MIMETYPE'
	PTYPE = TR + 'formatType'
	PUID = TR + 'PUID'
	XPUID = TR + 'XPUID'
	FILE_FORMAT = TR + 'file-format'
	FILE_EXT = TR + 'fileExtension'
	SOFTWARE_PACKAGE = TR + 'software-package'
	VERSION = TR + 'version'
	def subject_for(puid)
		raise "unrecognized PRONOM ID format \"#{puid}\"" unless puid =~ /^(x-)?fmt\//
		parts = puid.split('/')
        if parts[0] == 'fmt'
        	FORMAT_ID + parts[1]
        else
        	raise "Linked Data subjects for extension formats unknown"
        end
	end
	def self.statements_for_puid(puid, only_resource = false)
		statements_for_subject(subject_for(puid),only_resource)
	end
	def self.statements_for_subject(subject, only_resource = false)
		uri = QBASE % subject.split('/')[-1]
		RDF::Turtle::Reader.open(uri) do |rdr|
			rdr.each_statement { |stmt| yield stmt unless (only_resource && stmt.subject != subject)}
		end
	end
	def self.graph_for_puid(puid)
		graph_for_subject(subject_for(puid))
	end
	def self.graph_for_subject(subject)
		uri = QBASE % subject.split('/')[-1]
		graph = RDF::Graph.load(uri)
	end
end