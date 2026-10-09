class CreateRequestDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :request_drafts, id: :uuid do |t|
      t.references :need, type: :uuid, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.text     :gemini_raw
      t.string   :failure_reason
      t.datetime :generated_at

      t.string :title
      t.text   :description
      t.string :category
      t.text   :what_changed
      t.text   :missing_detail_question
      t.jsonb  :swap_terms, null: false, default: []

      t.timestamps null: false
    end
    add_index :request_drafts, :status
  end
end
