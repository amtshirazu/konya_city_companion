"""
===============================================================================
Konya City Companion — GTFS to SQLite Database Converter
===============================================================================
Description:
    This script converts the 11 raw static GTFS text files (agency.txt, stops.txt,
    routes.txt, trips.txt, stop_times.txt, calendar.txt, shapes.txt, etc.) from
    Konya Büyükşehir Belediyesi into a high-performance SQLite database (konya_gtfs.db).

Usage:
    python convert_gtfs_to_sqlite.py

Features:
    - Parses all 11 GTFS specification tables.
    - Creates primary keys and high-speed composite SQL indexes.
    - Optimized with PRAGMA synchronous = OFF and MEMORY journal mode.
    - Prepares konya_gtfs.db for instant on-device mobile transit query execution.
===============================================================================
"""

import csv
import os
import sqlite3
import time

# Path configurations
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
GTFS_DIR = os.path.join(PROJECT_ROOT, "gtfs_11_2025")
OUTPUT_DB = os.path.join(PROJECT_ROOT, "konya_gtfs.db")

print(f"Project Directory : {PROJECT_ROOT}")
print(f"GTFS Data Folder  : {GTFS_DIR}")
print(f"Output Database   : {OUTPUT_DB}")

# Remove existing DB file if present
if os.path.exists(OUTPUT_DB):
    try:
        os.remove(OUTPUT_DB)
        print("Removed existing konya_gtfs.db for a clean build.")
    except Exception as e:
        print(f"Notice: Could not remove old DB file: {e}")

conn = sqlite3.connect(OUTPUT_DB)
cursor = conn.cursor()

# Enable SQLite performance PRAGMAs for fast bulk loading
cursor.execute("PRAGMA synchronous = OFF;")
cursor.execute("PRAGMA journal_mode = MEMORY;")

# -----------------------------------------------------------------------------
# 1. SQL Schema Definitions (11 GTFS Specification Tables)
# -----------------------------------------------------------------------------
schema_statements = [
    """CREATE TABLE IF NOT EXISTS agency (
        agency_id TEXT PRIMARY KEY,
        agency_name TEXT NOT NULL,
        agency_url TEXT,
        agency_timezone TEXT,
        agency_lang TEXT,
        agency_phone TEXT,
        agency_fare_url TEXT,
        agency_email TEXT
    );""",
    """CREATE TABLE IF NOT EXISTS calendar (
        service_id TEXT PRIMARY KEY,
        monday INTEGER NOT NULL,
        tuesday INTEGER NOT NULL,
        wednesday INTEGER NOT NULL,
        thursday INTEGER NOT NULL,
        friday INTEGER NOT NULL,
        saturday INTEGER NOT NULL,
        sunday INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL
    );""",
    """CREATE TABLE IF NOT EXISTS calendar_dates (
        service_id TEXT NOT NULL,
        date TEXT NOT NULL,
        exception_type INTEGER NOT NULL,
        PRIMARY KEY (service_id, date)
    );""",
    """CREATE TABLE IF NOT EXISTS fare_attributes (
        agency_id TEXT,
        fare_id TEXT PRIMARY KEY,
        price REAL NOT NULL,
        currency_type TEXT NOT NULL,
        payment_method INTEGER NOT NULL,
        transfers INTEGER,
        transfer_duration INTEGER
    );""",
    """CREATE TABLE IF NOT EXISTS fare_rules (
        fare_id TEXT NOT NULL,
        route_id TEXT,
        origin_id TEXT,
        destination_id TEXT,
        contains_id TEXT
    );""",
    """CREATE TABLE IF NOT EXISTS feed_info (
        feed_publisher_name TEXT NOT NULL,
        feed_publisher_url TEXT NOT NULL,
        feed_lang TEXT NOT NULL,
        feed_start_date TEXT,
        feed_end_date TEXT,
        feed_version TEXT,
        feed_contact_email TEXT,
        feed_contact_url TEXT
    );""",
    """CREATE TABLE IF NOT EXISTS routes (
        route_id TEXT PRIMARY KEY,
        agency_id TEXT,
        route_short_name TEXT,
        route_long_name TEXT,
        route_desc TEXT,
        route_type INTEGER NOT NULL, -- 0 = Tram, 3 = Bus
        route_url TEXT,
        route_color TEXT,
        route_text_color TEXT
    );""",
    """CREATE TABLE IF NOT EXISTS stops (
        stop_id TEXT PRIMARY KEY,
        stop_name TEXT NOT NULL,
        stop_desc TEXT,
        stop_lat REAL NOT NULL,
        stop_lon REAL NOT NULL,
        zone_id TEXT,
        stop_url TEXT
    );""",
    """CREATE TABLE IF NOT EXISTS trips (
        route_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        trip_id TEXT PRIMARY KEY,
        trip_headsign TEXT,
        direction_id INTEGER,
        block_id TEXT,
        shape_id TEXT
    );""",
    """CREATE TABLE IF NOT EXISTS shapes (
        shape_id TEXT NOT NULL,
        shape_pt_lat REAL NOT NULL,
        shape_pt_lon REAL NOT NULL,
        shape_pt_sequence INTEGER NOT NULL,
        shape_dist_traveled REAL,
        PRIMARY KEY (shape_id, shape_pt_sequence)
    );""",
    """CREATE TABLE IF NOT EXISTS stop_times (
        trip_id TEXT NOT NULL,
        arrival_time TEXT NOT NULL,
        departure_time TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        stop_sequence INTEGER NOT NULL,
        stop_headsign TEXT,
        pickup_type INTEGER,
        drop_off_type INTEGER,
        shape_dist_traveled REAL,
        PRIMARY KEY (trip_id, stop_sequence)
    );"""
]

print("\nCreating 11 GTFS database tables...")
for stmt in schema_statements:
    cursor.execute(stmt)

# -----------------------------------------------------------------------------
# 2. Performance Indexes for Instant On-Device Query Execution
# -----------------------------------------------------------------------------
index_statements = [
    "CREATE INDEX IF NOT EXISTS idx_stops_name ON stops(stop_name);",
    "CREATE INDEX IF NOT EXISTS idx_stops_lat_lon ON stops(stop_lat, stop_lon);",
    "CREATE INDEX IF NOT EXISTS idx_routes_type ON routes(route_type);",
    "CREATE INDEX IF NOT EXISTS idx_trips_route ON trips(route_id);",
    "CREATE INDEX IF NOT EXISTS idx_trips_service ON trips(service_id);",
    "CREATE INDEX IF NOT EXISTS idx_trips_shape ON trips(shape_id);",
    "CREATE INDEX IF NOT EXISTS idx_stop_times_stop ON stop_times(stop_id);",
    "CREATE INDEX IF NOT EXISTS idx_stop_times_trip ON stop_times(trip_id);",
    "CREATE INDEX IF NOT EXISTS idx_stop_times_dept ON stop_times(departure_time);",
    "CREATE INDEX IF NOT EXISTS idx_shapes_id ON shapes(shape_id);"
]

print("Creating performance indexes...")
for stmt in index_statements:
    cursor.execute(stmt)

conn.commit()

# -----------------------------------------------------------------------------
# 3. CSV Bulk-Insertion Function
# -----------------------------------------------------------------------------
def load_csv_to_table(filename, table_name, columns):
    filepath = os.path.join(GTFS_DIR, filename)
    if not os.path.exists(filepath):
        print(f"Warning: File not found: {filename}")
        return

    start = time.time()
    with open(filepath, 'r', encoding='utf-8-sig', errors='replace') as fp:
        reader = csv.DictReader(fp)
        placeholders = ", ".join(["?"] * len(columns))
        col_names = ", ".join(columns)
        sql = f"INSERT INTO {table_name} ({col_names}) VALUES ({placeholders})"

        rows_to_insert = []
        count = 0
        for row in reader:
            vals = [row.get(col, None) for col in columns]
            rows_to_insert.append(vals)
            count += 1
            if len(rows_to_insert) >= 10000:
                cursor.executemany(sql, rows_to_insert)
                rows_to_insert.clear()

        if rows_to_insert:
            cursor.executemany(sql, rows_to_insert)

    conn.commit()
    elapsed = time.time() - start
    print(f"Loaded {count:7d} rows into {table_name:15s} in {elapsed:.2f}s")

files_mapping = [
    ("agency.txt", "agency", ["agency_id", "agency_name", "agency_url", "agency_timezone", "agency_lang", "agency_phone", "agency_fare_url", "agency_email"]),
    ("calendar.txt", "calendar", ["service_id", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "start_date", "end_date"]),
    ("calendar_dates.txt", "calendar_dates", ["service_id", "date", "exception_type"]),
    ("fare_attributes.txt", "fare_attributes", ["agency_id", "fare_id", "price", "currency_type", "payment_method", "transfers", "transfer_duration"]),
    ("fare_rules.txt", "fare_rules", ["fare_id", "route_id", "origin_id", "destination_id", "contains_id"]),
    ("feed_info.txt", "feed_info", ["feed_publisher_name", "feed_publisher_url", "feed_lang", "feed_start_date", "feed_end_date", "feed_version", "feed_contact_email", "feed_contact_url"]),
    ("routes.txt", "routes", ["route_id", "agency_id", "route_short_name", "route_long_name", "route_desc", "route_type", "route_url", "route_color", "route_text_color"]),
    ("stops.txt", "stops", ["stop_id", "stop_name", "stop_desc", "stop_lat", "stop_lon", "zone_id", "stop_url"]),
    ("trips.txt", "trips", ["route_id", "service_id", "trip_id", "trip_headsign", "direction_id", "block_id", "shape_id"]),
    ("shapes.txt", "shapes", ["shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence", "shape_dist_traveled"]),
    ("stop_times.txt", "stop_times", ["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence", "stop_headsign", "pickup_type", "drop_off_type", "shape_dist_traveled"])
]

print("\nBulk loading GTFS CSV files into SQLite...")
total_start = time.time()
for fname, tbl, cols in files_mapping:
    load_csv_to_table(fname, tbl, cols)

total_elapsed = time.time() - total_start
print(f"\n===============================================================================")
print(f"Successfully created '{OUTPUT_DB}' in {total_elapsed:.2f}s!")
print(f"Database File Size: {os.path.getsize(OUTPUT_DB) / (1024 * 1024):.2f} MB")
print(f"===============================================================================")

conn.close()
