#!/bin/bash
#
# Spin up a temporary PostgreSQL instance in tests/db/pgsql/
# populated with the spamikaze-pgsql-3 schema.
#
# Usage:
#   tests/db/setup-pgsql.sh start    # initialize and start
#   tests/db/setup-pgsql.sh stop     # stop and clean up
#   tests/db/setup-pgsql.sh status   # check if running
#
# The instance listens on a Unix socket only (no TCP port conflicts).
# Connection: psql -h tests/db/pgsql/socket -d psbl
#
# Environment variables for Perl DBI:
#   PGHOST=<abs path>/tests/db/pgsql/socket
#   PGDATABASE=psbl
#   PGUSER=psbl
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DBDIR="$SCRIPT_DIR/pgsql"
DATADIR="$DBDIR/data"
SOCKETDIR="$DBDIR/socket"
LOGFILE="$DBDIR/postgres.log"
DBNAME="psbl"
DBUSER="psbl"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA="$REPO_ROOT/schemas/spamikaze-pgsql-3.sql"

cmd="${1:-start}"

case "$cmd" in
    start)
        if [ -f "$DATADIR/postmaster.pid" ]; then
            echo "PostgreSQL already running (PID file exists)."
            echo "Run '$0 stop' first, or '$0 status' to check."
            exit 1
        fi

        echo "=== Setting up temporary PostgreSQL instance ==="

        # Clean up any previous state
        rm -rf "$DBDIR"
        mkdir -p "$DATADIR" "$SOCKETDIR"

        # Initialize the database cluster
        echo "Initializing database cluster..."
        initdb -D "$DATADIR" --auth=trust --no-locale -E UTF8 -U postgres >"$LOGFILE" 2>&1

        # Configure for socket-only access
        cat >> "$DATADIR/postgresql.conf" <<PGCONF
listen_addresses = ''
unix_socket_directories = '$SOCKETDIR'
logging_collector = off
PGCONF

        # Start the server
        echo "Starting PostgreSQL..."
        pg_ctl -D "$DATADIR" -l "$LOGFILE" -w start -o "-k $SOCKETDIR"

        # Create the database and user
        echo "Creating database '$DBNAME' and user '$DBUSER'..."
        psql -h "$SOCKETDIR" -U postgres -c "CREATE USER $DBUSER;" 2>/dev/null || true
        createdb -h "$SOCKETDIR" -U postgres -O "$DBUSER" "$DBNAME"

        # Load the schema
        echo "Loading schema from $SCHEMA..."
        psql -h "$SOCKETDIR" -U "$DBUSER" -d "$DBNAME" -f "$SCHEMA" >"$LOGFILE.schema" 2>&1

        echo ""
        echo "=== PostgreSQL is ready ==="
        echo "  Socket: $SOCKETDIR"
        echo "  Database: $DBNAME"
        echo "  User: $DBUSER"
        echo "  Log: $LOGFILE"
        echo ""
        echo "Connect with:"
        echo "  psql -h $SOCKETDIR -U $DBUSER -d $DBNAME"
        echo ""
        echo "Perl DBI DSN:"
        echo "  dbi:Pg:dbname=$DBNAME;host=$SOCKETDIR"
        ;;

    stop)
        if [ ! -d "$DATADIR" ]; then
            echo "No PostgreSQL data directory found."
            exit 0
        fi

        echo "Stopping PostgreSQL..."
        pg_ctl -D "$DATADIR" -m fast stop 2>/dev/null || true

        echo "Cleaning up $DBDIR..."
        rm -rf "$DBDIR"
        echo "Done."
        ;;

    status)
        if [ -f "$DATADIR/postmaster.pid" ] && pg_isready -h "$SOCKETDIR" -q 2>/dev/null; then
            echo "PostgreSQL is running."
            echo "  Socket: $SOCKETDIR"
            echo "  PID: $(head -1 "$DATADIR/postmaster.pid")"
            exit 0
        else
            echo "PostgreSQL is not running."
            exit 1
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
