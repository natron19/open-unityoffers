class CreateNeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :needs, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.text    :rough_text,  null: false
      t.string  :could_offer
      t.string  :categories,  null: false
      t.string  :time_window
      t.integer :hours

      t.timestamps null: false
    end
  end
end
