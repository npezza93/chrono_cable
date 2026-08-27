class CreateSolidCableChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cable_channels do |t|
      t.integer :channel_hash, limit: 8, null: false
      t.bigint :current_id, default: 0, null: false
      t.index :channel_hash, unique: true

      t.timestamps
    end
  end
end
