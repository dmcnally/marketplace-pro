class CreateIdentityBucket < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO buckets (name, created_at, updated_at)
      VALUES ('identity', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (name) DO NOTHING
    SQL

    execute <<~SQL.squish
      UPDATE recordings
      SET bucket_id = (SELECT id FROM buckets WHERE name = 'identity'),
          updated_at = CURRENT_TIMESTAMP
      WHERE recordable_type = 'PersonCard'
    SQL

    execute <<~SQL.squish
      UPDATE events
      SET bucket_id = (SELECT id FROM buckets WHERE name = 'identity')
      FROM recordings
      WHERE events.eventable_type = 'Recording'
        AND events.eventable_id = recordings.id
        AND recordings.recordable_type = 'PersonCard'
    SQL
  end

  def down
    # Historical identity ownership should not be moved back automatically.
  end
end
