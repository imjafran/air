-- Air Real-time Communication System (ArrayStory Air)
-- Database Schema

-- Rooms table
CREATE TABLE IF NOT EXISTS air_rooms (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    max_buffer_size BIGINT DEFAULT 32768 COMMENT 'Maximum message size in bytes (default 32KB)',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Whitelisted domains per room
CREATE TABLE IF NOT EXISTS air_room_domains (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    room_id BIGINT NOT NULL,
    domain VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES air_rooms(id) ON DELETE CASCADE,
    UNIQUE KEY unique_room_domain (room_id, domain),
    INDEX idx_room_id (room_id),
    INDEX idx_domain (domain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- API access tokens
CREATE TABLE IF NOT EXISTS air_api_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    token VARCHAR(255) UNIQUE NOT NULL,
    room_id BIGINT NOT NULL,
    name VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP NULL,
    FOREIGN KEY (room_id) REFERENCES air_rooms(id) ON DELETE CASCADE,
    INDEX idx_token (token),
    INDEX idx_active (is_active),
    INDEX idx_room_id (room_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert test data for development
INSERT INTO air_rooms (name, description, is_active) VALUES
('test', 'Test room for development', TRUE),
('demo', 'Demo room for testing features', TRUE);

INSERT INTO air_room_domains (room_id, domain) VALUES
(1, 'localhost'),
(1, '127.0.0.1'),
(2, 'localhost'),
(2, 'example.com');

INSERT INTO air_api_tokens (token, room_id, name, is_active) VALUES
('test-token-12345', 1, 'Development Token', TRUE),
('demo-token-67890', 2, 'Demo Token', TRUE);
