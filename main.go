package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gobwas/ws"
	"github.com/gobwas/ws/wsutil"
)

type Client struct {
	conn    net.Conn
	channel string
	id      string
	name    string
}

type Hub struct {
	clients   map[*Client]bool
	broadcast chan broadcastMessage
	mu        sync.RWMutex
	db        *sql.DB
}

type broadcastMessage struct {
	channel  string
	data     []byte
	sender   *Client // Track who sent the message
	target   *Client // Target client for direct messages
	msgType  string  // "broadcast", "direct", "typing", "userlist"
}

type UserInfo struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type MessagePayload struct {
	Type   string `json:"type"`           // "message", "direct", "typing", "join", "leave"
	Data   any    `json:"data,omitempty"`
	To     string `json:"to,omitempty"`     // Target user ID for direct messages
	From   string `json:"from,omitempty"`   // Sender user ID
	Sender string `json:"sender,omitempty"` // Sender name
	Users  []UserInfo `json:"users,omitempty"` // User list
}

type Room struct {
	ID            int64
	Name          string
	Description   string
	MaxBufferSize int64
	IsActive      bool
}

type APIToken struct {
	ID         int64
	Token      string
	RoomID     int64
	RoomName   string
	Name       string
	IsActive   bool
	ExpiresAt  *time.Time
	LastUsedAt *time.Time
}

func NewHub(db *sql.DB) *Hub {
	return &Hub{
		clients:   make(map[*Client]bool),
		broadcast: make(chan broadcastMessage, 100),
		db:        db,
	}
}

func jsonError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	fmt.Fprintf(w, `{"error":"%s"}`, message)
}

func (h *Hub) validateToken(token string) (*APIToken, error) {
	var apiToken APIToken
	query := `SELECT t.id, t.token, t.room_id, r.name, t.name, t.is_active, t.expires_at, t.last_used_at
	          FROM air_api_tokens t
	          JOIN air_rooms r ON t.room_id = r.id
	          WHERE t.token = ? AND t.is_active = TRUE AND r.is_active = TRUE`

	err := h.db.QueryRow(query, token).Scan(
		&apiToken.ID,
		&apiToken.Token,
		&apiToken.RoomID,
		&apiToken.RoomName,
		&apiToken.Name,
		&apiToken.IsActive,
		&apiToken.ExpiresAt,
		&apiToken.LastUsedAt,
	)

	if err != nil {
		return nil, err
	}

	// Check if token is expired
	if apiToken.ExpiresAt != nil && apiToken.ExpiresAt.Before(time.Now()) {
		return nil, fmt.Errorf("token expired")
	}

	// Update last_used_at
	go func() {
		_, _ = h.db.Exec("UPDATE air_api_tokens SET last_used_at = ? WHERE id = ?", time.Now(), apiToken.ID)
	}()

	return &apiToken, nil
}

func (h *Hub) validateRoom(roomName string) (*Room, error) {
	var room Room
	query := `SELECT id, name, description, max_buffer_size, is_active
	          FROM air_rooms
	          WHERE name = ? AND is_active = TRUE`

	err := h.db.QueryRow(query, roomName).Scan(
		&room.ID,
		&room.Name,
		&room.Description,
		&room.MaxBufferSize,
		&room.IsActive,
	)

	if err != nil {
		return nil, err
	}

	return &room, nil
}

func (h *Hub) validateOrigin(roomID int64, origin string) (bool, error) {
	if origin == "" {
		return false, nil
	}

	// Extract hostname from origin (strip protocol and port)
	// e.g., "http://localhost:8282" -> "localhost"
	// e.g., "https://example.com:3000" -> "example.com"
	hostname := origin

	// Remove protocol
	if idx := strings.Index(hostname, "://"); idx != -1 {
		hostname = hostname[idx+3:]
	}

	// Remove port
	if idx := strings.Index(hostname, ":"); idx != -1 {
		hostname = hostname[:idx]
	}

	// Check if domain is whitelisted for this room
	var count int
	query := `SELECT COUNT(*) FROM air_room_domains
	          WHERE room_id = ? AND domain = ?`

	err := h.db.QueryRow(query, roomID, hostname).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

func (h *Hub) getUserList(channel string) []UserInfo {
	users := []UserInfo{}
	h.mu.RLock()
	for client := range h.clients {
		if client.channel == channel {
			users = append(users, UserInfo{
				ID:   client.id,
				Name: client.name,
			})
		}
	}
	h.mu.RUnlock()
	return users
}

func (h *Hub) broadcastUserList(channel string) {
	users := h.getUserList(channel)
	payload := MessagePayload{
		Type:  "userlist",
		Users: users,
	}
	data, _ := json.Marshal(payload)

	h.mu.RLock()
	for client := range h.clients {
		if client.channel == channel {
			wsutil.WriteServerMessage(client.conn, ws.OpText, data)
		}
	}
	h.mu.RUnlock()
}

func (h *Hub) run() {
	for {
		msg := <-h.broadcast
		h.mu.RLock()

		switch msg.msgType {
		case "direct":
			// Send to specific target only
			if msg.target != nil {
				wsutil.WriteServerMessage(msg.target.conn, ws.OpText, msg.data)
			}

		case "typing":
			// Broadcast typing indicator to all except sender
			for client := range h.clients {
				if client.channel == msg.channel && client != msg.sender {
					wsutil.WriteServerMessage(client.conn, ws.OpText, msg.data)
				}
			}

		case "userlist":
			// Broadcast user list to all in channel
			for client := range h.clients {
				if client.channel == msg.channel {
					wsutil.WriteServerMessage(client.conn, ws.OpText, msg.data)
				}
			}

		default: // "broadcast"
			// Send to all clients in the same channel, except sender
			for client := range h.clients {
				if client.channel == msg.channel && client != msg.sender {
					wsutil.WriteServerMessage(client.conn, ws.OpText, msg.data)
				}
			}
		}

		h.mu.RUnlock()
	}
}

func (h *Hub) findClientByID(channel, userID string) *Client {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for client := range h.clients {
		if client.channel == channel && client.id == userID {
			return client
		}
	}
	return nil
}

func (h *Hub) handleAirJS(w http.ResponseWriter, r *http.Request) {
	// Get origin or referer to validate
	origin := r.Header.Get("Origin")
	if origin == "" {
		origin = r.Header.Get("Referer")
	}

	// Extract hostname
	hostname := origin
	if idx := strings.Index(hostname, "://"); idx != -1 {
		hostname = hostname[idx+3:]
	}
	if idx := strings.Index(hostname, "/"); idx != -1 {
		hostname = hostname[:idx]
	}
	if idx := strings.Index(hostname, ":"); idx != -1 {
		hostname = hostname[:idx]
	}

	// Check if domain is in any room's whitelist
	var count int
	query := `SELECT COUNT(*) FROM air_room_domains WHERE domain = ?`
	err := h.db.QueryRow(query, hostname).Scan(&count)

	if err != nil || count == 0 {
		http.Error(w, "Access denied", http.StatusForbidden)
		return
	}

	// Serve the air.js file
	w.Header().Set("Content-Type", "application/javascript")
	w.Header().Set("Access-Control-Allow-Origin", origin)
	w.Header().Set("Cache-Control", "public, max-age=3600")

	http.ServeFile(w, r, "./public/air.prod.js")
}

func (h *Hub) handleEmit(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get token from Authorization header
	token := r.Header.Get("Authorization")
	if token == "" {
		jsonError(w, "Authorization token required", http.StatusUnauthorized)
		return
	}

	// Strip "Bearer " prefix if present
	if len(token) > 7 && token[:7] == "Bearer " {
		token = token[7:]
	}

	// Validate token and get associated room
	apiToken, err := h.validateToken(token)
	if err != nil {
		jsonError(w, "Invalid or expired token", http.StatusUnauthorized)
		return
	}

	// Parse entire JSON body as data to broadcast
	var data map[string]any
	err = json.NewDecoder(r.Body).Decode(&data)
	if err != nil {
		jsonError(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Convert data to JSON bytes
	dataBytes, err := json.Marshal(data)
	if err != nil {
		jsonError(w, "Error encoding data", http.StatusBadRequest)
		return
	}

	// Validate room and get max buffer size
	room, err := h.validateRoom(apiToken.RoomName)
	if err != nil {
		jsonError(w, "Invalid or inactive room", http.StatusNotFound)
		return
	}

	// Check message size against room's max buffer size
	messageSize := int64(len(dataBytes))
	if messageSize > room.MaxBufferSize {
		jsonError(w, fmt.Sprintf("Message size %d bytes exceeds room limit of %d bytes", messageSize, room.MaxBufferSize), http.StatusRequestEntityTooLarge)
		return
	}

	// Broadcast to all clients in the token's room (sender is nil for API calls)
	h.broadcast <- broadcastMessage{
		channel: apiToken.RoomName,
		data:    dataBytes,
		sender:  nil,
		msgType: "broadcast",
	}

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"success":true,"room":"%s"}`, apiToken.RoomName)
}

func (h *Hub) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	origin := r.Header.Get("Origin")

	// Get channel from query parameter
	channel := r.URL.Query().Get("channel")
	if channel == "" {
		http.Error(w, "channel query parameter required", http.StatusBadRequest)
		return
	}

	// Get user info from query parameters
	userID := r.URL.Query().Get("id")
	userName := r.URL.Query().Get("name")
	if userID == "" || userName == "" {
		http.Error(w, "id and name query parameters required", http.StatusBadRequest)
		return
	}

	// Validate room exists
	room, err := h.validateRoom(channel)
	if err != nil {
		http.Error(w, "Invalid or inactive room", http.StatusNotFound)
		return
	}

	// Validate origin against room's whitelist
	allowed, err := h.validateOrigin(room.ID, origin)
	if err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	if !allowed {
		http.Error(w, "Origin not allowed", http.StatusForbidden)
		return
	}

	// Upgrade with NO compression - gobwas/ws doesn't negotiate compression by default
	conn, _, _, err := ws.UpgradeHTTP(r, w)
	if err != nil {
		return
	}
	defer conn.Close()

	// Create client with channel, id and name
	client := &Client{
		conn:    conn,
		channel: channel,
		id:      userID,
		name:    userName,
	}

	// Register client
	h.mu.Lock()
	h.clients[client] = true
	h.mu.Unlock()

	// Broadcast user joined
	joinPayload := MessagePayload{
		Type:   "join",
		From:   userID,
		Sender: userName,
	}
	joinData, _ := json.Marshal(joinPayload)
	h.broadcast <- broadcastMessage{
		channel: channel,
		data:    joinData,
		sender:  client,
		msgType: "broadcast",
	}

	// Broadcast updated user list
	h.broadcastUserList(channel)

	// Cleanup on disconnect
	defer func() {
		h.mu.Lock()
		delete(h.clients, client)
		h.mu.Unlock()

		// Broadcast user left
		leavePayload := MessagePayload{
			Type:   "leave",
			From:   userID,
			Sender: userName,
		}
		leaveData, _ := json.Marshal(leavePayload)
		h.broadcast <- broadcastMessage{
			channel: channel,
			data:    leaveData,
			sender:  nil,
			msgType: "broadcast",
		}

		// Broadcast updated user list
		h.broadcastUserList(channel)
	}()

	// Read messages
	for {
		msg, op, err := wsutil.ReadClientData(conn)
		if err != nil {
			break
		}

		// Handle different operation codes
		switch op {
		case ws.OpText:
			// Parse message as JSON
			var payload map[string]any
			err := json.Unmarshal(msg, &payload)
			if err != nil {
				continue
			}

			msgChannel, channelOk := payload["channel"].(string)
			msgType, typeOk := payload["type"].(string)

			if !channelOk {
				continue
			}

			// Only allow messages to the client's own channel
			if msgChannel != channel {
				continue
			}

			// Default type is "message"
			if !typeOk {
				msgType = "message"
			}

			switch msgType {
			case "typing":
				// Broadcast typing indicator
				typingPayload := MessagePayload{
					Type:   "typing",
					From:   userID,
					Sender: userName,
				}
				typingData, _ := json.Marshal(typingPayload)
				h.broadcast <- broadcastMessage{
					channel: channel,
					data:    typingData,
					sender:  client,
					msgType: "typing",
				}

			case "direct":
				// Send direct message to specific user
				targetID, targetOk := payload["to"].(string)
				msgData, dataOk := payload["data"]

				if !targetOk || !dataOk {
					continue
				}

				// Find target client
				targetClient := h.findClientByID(channel, targetID)
				if targetClient == nil {
					continue
				}

				// Prepare direct message
				directPayload := MessagePayload{
					Type:   "direct",
					From:   userID,
					Sender: userName,
					Data:   msgData,
				}
				directData, _ := json.Marshal(directPayload)

				// Check message size
				messageSize := int64(len(directData))
				if messageSize > room.MaxBufferSize {
					errMsg := fmt.Sprintf(`{"error":"Message size %d bytes exceeds room limit of %d bytes"}`, messageSize, room.MaxBufferSize)
					wsutil.WriteServerMessage(conn, ws.OpText, []byte(errMsg))
					continue
				}

				h.broadcast <- broadcastMessage{
					channel: channel,
					data:    directData,
					sender:  client,
					target:  targetClient,
					msgType: "direct",
				}

			default: // "message" or any other type - broadcast to all
				msgData, dataOk := payload["data"]
				if !dataOk {
					continue
				}

				// Prepare broadcast message
				broadcastPayload := MessagePayload{
					Type:   "message",
					From:   userID,
					Sender: userName,
					Data:   msgData,
				}
				broadcastData, err := json.Marshal(broadcastPayload)
				if err != nil {
					continue
				}

				// Check message size
				messageSize := int64(len(broadcastData))
				if messageSize > room.MaxBufferSize {
					errMsg := fmt.Sprintf(`{"error":"Message size %d bytes exceeds room limit of %d bytes"}`, messageSize, room.MaxBufferSize)
					wsutil.WriteServerMessage(conn, ws.OpText, []byte(errMsg))
					continue
				}

				h.broadcast <- broadcastMessage{
					channel: channel,
					data:    broadcastData,
					sender:  client,
					msgType: "broadcast",
				}
			}

		case ws.OpPing:
			// Respond to ping with pong
			err := wsutil.WriteServerMessage(conn, ws.OpPong, msg)
			if err != nil {
				return
			}

		case ws.OpClose:
			// Client requested close
			return
		}
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func main() {
	// Database configuration from environment
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "3306")
	dbUser := getEnv("DB_USER", "air_user")
	dbPass := getEnv("DB_PASSWORD", "")
	dbName := getEnv("DB_NAME", "air_production")

	// Create database connection string
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true", dbUser, dbPass, dbHost, dbPort, dbName)

	// Connect to database
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Test database connection
	err = db.Ping()
	if err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	// Create hub with database connection
	hub := NewHub(db)
	go hub.run()

	// WebSocket endpoint
	http.HandleFunc("/ws", hub.handleWebSocket)

	// HTTP API endpoint to emit messages
	http.HandleFunc("/emit", hub.handleEmit)

	// Client library with CORS protection
	http.HandleFunc("/air.js", hub.handleAirJS)

	// Serve static files
	http.Handle("/", http.FileServer(http.Dir("./public")))

	port := getEnv("AIR_PORT", "8181")
	log.Fatal(http.ListenAndServe(":"+port, nil))
}