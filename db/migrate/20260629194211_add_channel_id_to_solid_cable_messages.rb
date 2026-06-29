class AddChannelIdToSolidCableMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :solid_cable_messages, :channel_id, :integer, if_not_exists: true
  end
end
