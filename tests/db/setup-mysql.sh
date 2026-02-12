#!/bin/bash
#
# Spin up a temporary MariaDB/MySQL instance in tests/db/mysql/
# populated with the spamikaze-mysql-3 schema.
#
# Usage:
#   tests/db/setup-mysql.sh start    # initialize and start
#   tests/db/setup-mysql.sh stop     # stop and clean up
#   tests/db/setup-mysql.sh status   # check if running
#
# The instance listens on a Unix socket only (no TCP port conflicts).
# It runs with --skip-grant-tables so any user name works.
# Connection: mariadb -S tests/db/mysql/socket/mysql.sock psbl
#
# Perl DBI DSN:
#   dbi:mysql:database=psbl;mysql_socket=<abs path>/tests/db/mysql/socket/mysql.sock
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DBDIR="$SCRIPT_DIR/mysql"
DATADIR="$DBDIR/data"
SOCKETDIR="$DBDIR/socket"
SOCKET="$SOCKETDIR/mysql.sock"
LOGFILE="$DBDIR/mariadb.log"
PIDFILE="$DBDIR/mariadb.pid"
TMPDIR="$DBDIR/tmp"
DBNAME="psbl"
DBUSER="psbl"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA="$REPO_ROOT/schemas/spamikaze-mysql-3.sql"

cmd="${1:-start}"

case "$cmd" in
    start)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "MariaDB already running (PID $(cat "$PIDFILE"))."
            echo "Run '$0 stop' first, or '$0 status' to check."
            exit 1
        fi

        echo "=== Setting up temporary MariaDB instance ==="

        # Clean up any previous state
        rm -rf "$DBDIR"
        mkdir -p "$DATADIR" "$SOCKETDIR" "$TMPDIR"

        # Initialize the database
        echo "Initializing database..."
        mariadb-install-db \
            --datadir="$DATADIR" \
            --auth-root-authentication-method=normal \
            --skip-test-db \
            >"$LOGFILE" 2>&1

        # Start the server
        echo "Starting MariaDB..."
        mariadbd \
            --datadir="$DATADIR" \
            --socket="$SOCKET" \
            --pid-file="$PIDFILE" \
            --log-error="$LOGFILE" \
            --tmpdir="$TMPDIR" \
            --skip-networking \
            --skip-grant-tables &

        # Wait for the server to be ready
        echo -n "Waiting for MariaDB to start"
        for i in $(seq 1 30); do
            if mariadb -S "$SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1; then
                echo " ready."
                break
            fi
            echo -n "."
            sleep 1
        done

        if ! mariadb -S "$SOCKET" -u root -e "SELECT 1" >/dev/null 2>&1; then
            echo " FAILED."
            echo "Check $LOGFILE for details."
            exit 1
        fi

        # Create the database
        echo "Creating database '$DBNAME'..."
        mariadb -S "$SOCKET" -u root -e "CREATE DATABASE IF NOT EXISTS $DBNAME CHARACTER SET utf8mb4;"

        # Load the schema
        echo "Loading schema from $SCHEMA..."
        mariadb -S "$SOCKET" -u root "$DBNAME" < "$SCHEMA"

        echo ""
        echo "=== MariaDB is ready ==="
        echo "  Socket: $SOCKET"
        echo "  Database: $DBNAME"
        echo "  Log: $LOGFILE"
        echo "  PID: $(cat "$PIDFILE")"
        echo ""
        echo "Connect with:"
        echo "  mariadb -S $SOCKET $DBNAME"
        echo ""
        echo "Perl DBI DSN:"
        echo "  dbi:mysql:database=$DBNAME;mysql_socket=$SOCKET"
        ;;

    stop)
        if [ ! -f "$PIDFILE" ]; then
            echo "No MariaDB PID file found."
            # Try to clean up anyway
            rm -rf "$DBDIR"
            exit 0
        fi

        echo "Stopping MariaDB..."
        local_pid="$(cat "$PIDFILE" 2>/dev/null || true)"
        if [ -n "$local_pid" ]; then
            kill "$local_pid" 2>/dev/null || true
            # Wait for shutdown
            for i in $(seq 1 10); do
                if ! kill -0 "$local_pid" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            # Force kill if still running
            kill -9 "$local_pid" 2>/dev/null || true
        fi

        echo "Cleaning up $DBDIR..."
        rm -rf "$DBDIR"
        echo "Done."
        ;;

    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "MariaDB is running."
            echo "  Socket: $SOCKET"
            echo "  PID: $(cat "$PIDFILE")"
            exit 0
        else
            echo "MariaDB is not running."
            exit 1
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
