class AddRedirectsTable < ActiveRecord::Migration[4.2]
  def self.up
    create_table :redirects do |t|
      t.string :pattern
      t.string :to
    end
  end

  def self.down
    drop_table :redirects
  end
end
