class AddChannelIdToSolidCableMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :solid_cable_messages, :channel_id, :bigint, if_not_exists: true
    add_index :solid_cable_messages, [ :channel_hash, :channel_id ], unique: true,
      if_not_exists: true
  end
end
