class CreateThanks < ActiveRecord::Migration
  def self.up
    create_table :thanks do |t|
      t.string :name
      t.text :message
      t.timestamps
    end
  end

  def self.down
    drop_table :thanks
  end
end
