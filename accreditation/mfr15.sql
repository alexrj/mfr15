CREATE DATABASE mfr15 CHARACTER SET utf8 COLLATE utf8_unicode_ci;

CREATE TABLE exhibits (
    id INTEGER UNSIGNED NOT NULL,
    oid VARCHAR(32) NOT NULL,
    category VARCHAR(255),
    badges_category ENUM('maker','partner','speaker') NOT NULL,
    exhibitor_name TEXT NOT NULL,
    title TEXT NOT NULL,
    max_setup_badges INTEGER UNSIGNED NOT NULL,
    max_event_badges INTEGER UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE(oid)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;

CREATE TABLE locations (
    oid VARCHAR(32) NOT NULL,
    exhibit_oid VARCHAR(32) NOT NULL,
    public_name VARCHAR(10) NOT NULL,
    gate SMALLINT,
    PRIMARY KEY (oid),
    INDEX(exhibit_oid),
    INDEX(public_name)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;

CREATE TABLE projects (
    id INTEGER UNSIGNED NOT NULL,
    oid VARCHAR(32) NOT NULL,
    exhibit_oid VARCHAR(32) NOT NULL,
    title TEXT,
    author TEXT,
    PRIMARY KEY (oid)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;

CREATE TABLE events (
    id VARCHAR(5) NOT NULL,
    oid VARCHAR(32) NOT NULL,
    title TEXT NOT NULL,
    speaker TEXT NOT NULL,
    category VARCHAR(255),
    badges_category ENUM('maker','partner','speaker') NOT NULL,
    max_badges INTEGER UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE(oid)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;

CREATE TABLE badges (
    local_id INTEGER UNSIGNED AUTO_INCREMENT,
    oid VARCHAR(32),
    exhibit_oid VARCHAR(32),
    event_oid VARCHAR(32),
    badge_type ENUM('setup','event') NOT NULL,
    name VARCHAR(255) NOT NULL,
    lastname VARCHAR(255) NOT NULL,
    checkin DATETIME,
    checkin_person VARCHAR(255),
    checkin_person_contact VARCHAR(255),
    to_sync BOOL NOT NULL,
    PRIMARY KEY (local_id),
    UNIQUE(oid),
    INDEX(exhibit_oid),
    INDEX(event_oid)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;

CREATE TABLE badges_import (
    oid VARCHAR(32) NOT NULL,
    exhibit_oid VARCHAR(32),
    event_oid VARCHAR(32),
    badge_type ENUM('setup','event') NOT NULL,
    name VARCHAR(255) NOT NULL,
    lastname VARCHAR(255) NOT NULL,
    checkin DATETIME,
    checkin_person VARCHAR(255),
    checkin_person_contact VARCHAR(255),
    PRIMARY KEY (oid),
    INDEX(exhibit_oid),
    INDEX(event_oid)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;
