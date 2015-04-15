class PronomFormat < ActiveRecord::Base
	self.primary_key = "id"
	has_many :pronom_format_type
end