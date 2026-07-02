class CreatePlansAndAddPlanToCompanies < ActiveRecord::Migration[7.1]
  def change
    create_table :plans do |t|
      t.string  :name,          null: false
      t.integer :events_limit                  # nil = ilimitado
      t.integer :members_limit                 # nil = ilimitado
      t.text    :description
      t.timestamps
    end

    add_index :plans, :name, unique: true

    add_reference :companies, :plan, null: true, foreign_key: true
  end
end
