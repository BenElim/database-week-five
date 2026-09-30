-- =====================================================================
-- answer.sql : PostgreSQL Backup, Recovery and Replication Lab
-- Database: bootcamp
-- Lines starting with "-- $" are shell commands (run in a terminal).
-- Everything else is SQL (run in psql).
-- =====================================================================


-- =====================================================================
-- STEP 1: Take and verify a logical backup
-- =====================================================================
-- $ mkdir -p ~/backups
-- $ pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp
-- $ pg_restore --list ~/backups/bootcamp.dump | head
-- $ createdb bootcamp_check
-- $ pg_restore -d bootcamp_check ~/backups/bootcamp.dump

-- Verify the restored copy matches the original (run in each database):
SELECT count(*) FROM students;

-- Clean up:
-- $ dropdb bootcamp_check


-- =====================================================================
-- STEP 2: Enable WAL archiving and take a base backup
-- =====================================================================
-- $ mkdir -p ~/backups/wal
-- (the postgres OS user must be able to write here; an absolute path is safer)
--
-- In postgresql.conf:
--   wal_level = replica
--   archive_mode = on
--   archive_command = 'test ! -f /home/USER/backups/wal/%f && cp %p /home/USER/backups/wal/%f'
--
-- $ sudo systemctl restart postgresql
-- $ pg_basebackup -D ~/backups/base -Ft -z -Xs -P

-- Confirm archiving works:
SELECT archived_count, last_archived_wal, failed_count FROM pg_stat_archiver;


-- =====================================================================
-- STEP 3: Simulate a disaster and recover (point-in-time recovery)
-- =====================================================================
SELECT now();          -- record this time, e.g. 2026-09-30 10:00:00
SELECT pg_switch_wal();  -- force the current WAL segment to be archived

DELETE FROM students;  -- oops

-- Recovery:
-- 1. $ sudo systemctl stop postgresql
-- 2. Move the old data directory aside, then extract base.tar.gz (and
--    pg_wal.tar.gz) from ~/backups/base into a fresh data directory.
--    $ sudo chown -R postgres:postgres <datadir> && sudo chmod 700 <datadir>
-- 3. In postgresql.conf set (use absolute paths, "~" is not expanded):
--      restore_command = 'cp /home/USER/backups/wal/%f %p'
--      recovery_target_time = '2026-09-30 10:00:00'
--      recovery_target_action = 'promote'
--    Then create an empty recovery.signal file in the data directory:
--    $ touch <datadir>/recovery.signal
-- 4. $ sudo systemctl start postgresql
-- 5. Verify recovery:
SELECT count(*) FROM students;


-- =====================================================================
-- STEP 4: Set up a streaming standby
-- =====================================================================
-- On the primary:
CREATE ROLE replicator
WITH REPLICATION LOGIN PASSWORD 'reppass';

-- In pg_hba.conf:
--   host replication replicator 127.0.0.1/32 md5
-- then reload:
SELECT pg_reload_conf();

-- Build the standby (separate data directory):
-- $ pg_basebackup -h 127.0.0.1 -U replicator -D ~/standby -R -P
-- $ chmod 700 ~/standby
-- Set port = 5433 in ~/standby/postgresql.conf (same machine as primary), then:
-- $ pg_ctl -D ~/standby start

-- Confirm the standby is in recovery (run with: psql -p 5433):
SELECT pg_is_in_recovery();  -- expected: t


-- =====================================================================
-- STEP 5: Watch replication health (run on the primary)
-- =====================================================================
SELECT application_name,
       state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;


-- =====================================================================
-- Wrap-up
-- =====================================================================
-- Protected the bootcamp database with a logical backup, recovered it to a
-- precise moment after a simulated failure using WAL archiving and a base
-- backup, and configured a live streaming standby replica.
