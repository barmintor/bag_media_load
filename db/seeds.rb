# ruby encoding: utf-8
open('fixtures/data/pronom_formats.txt') do |blob|
	
	blob.each do |line|
		line.chomp!
		parts = line.split("\t")
		PronomFormat.create(id: parts[0], uri: parts[1], pcdm_type: parts[3])
		ptypes = parts[2].split(',')
        ptypes.delete('')
        ptypes.each do |ptype|		
			PronomFormatType.create(pronom_format_type: ptype, pronom_format_id: parts[0])
		end
	end
end
