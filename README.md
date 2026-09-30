# PostgreSQL Backup, Recovery and Replication Lab

This repository contains my answers for the PostgreSQL backup and recovery lab, using the `bootcamp` database. All steps are in [`answer.sql`](answer.sql). SQL statements run as-is in `psql`, and shell commands and config edits are included as comments.

## What this lab covers

| Step | Topic | What I did |
|------|-------|------------|
| 1 | Logical backup | Dumped `bootcamp` with `pg_dump -Fc`, listed the archive with `pg_restore --list`, and restored it into a scratch database (`bootcamp_check`) to prove the backup works. |
| 2 | WAL archiving | Set `wal_level = replica`, `archive_mode = on` and an `archive_command`, then took a base backup with `pg_basebackup`. |
| 3 | Point-in-time recovery | Recorded the time with `SELECT now()`, deleted the `students` data, then restored the base backup and replayed archived WAL up to just before the deletion using `restore_command` and `recovery_target_time`. |
| 4 | Streaming standby | Created a `replicator` role with `REPLICATION LOGIN`, allowed it in `pg_hba.conf`, and built a standby with `pg_basebackup -R`. |
| 5 | Replication health | Checked standby state and lag in bytes using `pg_stat_replication` and `pg_wal_lsn_diff`. |

## Requirements

- PostgreSQL 12 or later (recovery uses `recovery.signal` and `standby.signal`, not `recovery.conf`)
- A `bootcamp` database containing a `students` table
- `sudo` access to restart PostgreSQL and manage the data directory

## How to use

1. Open `answer.sql` and replace `USER` in the paths with your own username.
2. Run the shell steps in a terminal and the SQL steps in `psql -d bootcamp`.
3. In Step 3, replace the example timestamp with the one returned by your own `SELECT now()`.

## Verification

- **Step 1:** `SELECT count(*) FROM students;` returns the same count in `bootcamp` and `bootcamp_check`.
- **Step 2:** `SELECT * FROM pg_stat_archiver;` shows archived WAL files and `failed_count = 0`.
- **Step 3:** After recovery, `SELECT count(*) FROM students;` returns the row count from before the `DELETE`.
- **Step 4:** On the standby, `SELECT pg_is_in_recovery();` returns `t`.
- **Step 5:** `pg_stat_replication` shows the standby with `state = streaming` and a small `lag_bytes`.

## Notes

- `archive_command` runs as the `postgres` OS user, so it uses absolute paths and a directory that user can write to.
- Old data directories are moved aside rather than deleted before recovery.
- The standby runs on the same machine, so it uses port `5433`.
- The `reppass` password is for lab use only. Use a strong password and restricted `pg_hba.conf` rules in real environments.

## Conclusion

I protected a database with a logical backup, recovered it to a precise moment after a simulated failure using WAL archiving and a base backup, and configured a live streaming standby replica.
