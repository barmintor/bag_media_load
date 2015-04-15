class CreatePronomTables < ActiveRecord::Migration
  def change
		create_table :pronom_formats, id: false do |t|
			t.string :id, null: false, primary_key: true
			t.string :uri
			t.string :pcdm_type
			t.index :uri
			t.index :pcdm_type
		end
		create_table :pronom_format_types do |t|
			t.string :pronom_format_type
			t.index :pronom_format_type
			t.string :pronom_format_id
			t.index :pronom_format_id
			t.foreign_key :pronom_formats, dependent: :delete
		end
	end
end
