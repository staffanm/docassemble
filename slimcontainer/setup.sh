#!/bin/bash
set -e
echo "creating the tables in postgres"
python -m docassemble.webapp.create_tables /usr/share/docassemble/config/config.yml www-data
echo "everything is ready to start for realz. running the real CMD ($@)"
exec "$@"