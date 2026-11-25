CREATE DATABASE IF NOT EXISTS lapak8
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE lapak8;

CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) NOT NULL PRIMARY KEY,
  identifier VARCHAR(120) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(160) NOT NULL,
  role ENUM('student', 'teacher', 'admin', 'sarpras') NOT NULL,
  classroom VARCHAR(80) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS facilities (
  id CHAR(36) NOT NULL PRIMARY KEY,
  name VARCHAR(160) NOT NULL,
  location VARCHAR(200) NOT NULL DEFAULT '',
  stock INT UNSIGNED NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT chk_facilities_stock CHECK (stock > 0),
  INDEX idx_facilities_active (is_active, name)
);

CREATE TABLE IF NOT EXISTS borrowings (
  id CHAR(36) NOT NULL PRIMARY KEY,
  code VARCHAR(32) NOT NULL UNIQUE,
  user_id CHAR(36) NOT NULL,
  facility_id CHAR(36) NOT NULL,
  category ENUM('praktik', 'ekskul', 'lainnya') NOT NULL,
  event_name VARCHAR(160) NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  start_at DATETIME(3) NOT NULL,
  end_at DATETIME(3) NOT NULL,
  status ENUM('pending', 'approved', 'rejected', 'borrowed', 'returned', 'cancelled')
    NOT NULL DEFAULT 'pending',
  decision_note VARCHAR(500) NULL,
  decided_by CHAR(36) NULL,
  decided_at DATETIME(3) NULL,
  checked_out_at DATETIME(3) NULL,
  returned_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT chk_borrowings_quantity CHECK (quantity > 0),
  CONSTRAINT chk_borrowings_range CHECK (end_at > start_at),
  CONSTRAINT fk_borrowings_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_borrowings_facility FOREIGN KEY (facility_id) REFERENCES facilities(id),
  CONSTRAINT fk_borrowings_decider FOREIGN KEY (decided_by) REFERENCES users(id),
  INDEX idx_borrowings_user (user_id, created_at),
  INDEX idx_borrowings_facility_schedule (facility_id, status, start_at, end_at),
  INDEX idx_borrowings_status (status, created_at)
);

INSERT IGNORE INTO facilities (id, name, location, stock)
VALUES (
  '00000000-0000-4000-8000-000000000001',
  'Laboratorium Komputer & RPL 1',
  'Gedung Praktik Lt. 1',
  1
);
