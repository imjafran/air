# AirSocket API Documentation

Complete guide for using AirSocket real-time communication system by ArrayStory.

## Table of Contents

- [JavaScript Client](#javascript-client)
- [HTTP API](#http-api)
- [Authentication](#authentication)
- [Database Management](#database-management)
- [Code Examples](#code-examples)

---

## JavaScript Client

### Installation

**Via CDN:**

```html
<script src="https://air.arraystory.com/air.js"></script>
```

**Via NPM/Local:**

```html
<script src="/air.js"></script>
```

### Quick Start

```javascript
// Initialize Air client with user info
const air = new Air('room-name', {
    id: 'user123',      // Optional: Auto-generated if not provided
    name: 'John Doe'    // Optional: Defaults to 'Anonymous'
});

// Listen for connection
air.onConnect(({ room, id, name }) => {
    console.log(`Connected to ${room} as ${name}!`);
});

// Listen for messages
air.onMessage((msg) => {
    console.log(`${msg.sender}:`, msg.data);
});

// Listen for user list updates
air.onUserList((users) => {
    console.log(`${users.length} users online:`, users);
});

// Connect to server
air.connect();

// Send message to everyone
air.send({ message: 'Hello World!' });

// Send direct message to specific user
air.sendTo('user456', { message: 'Hi there!' });

// Send typing indicator
air.typing();
```

---

## Client API Reference

### Constructor

```javascript
const air = new Air(room, options);
```

**Parameters:**
- `room` (string): Room name to join
- `options` (object, optional): Configuration object
  - `id` (string, optional): Custom user ID (auto-generated if not provided)
  - `name` (string, optional): User display name (defaults to 'Anonymous')

**Examples:**
```javascript
// Basic usage
const chatRoom = new Air('chat');

// With custom user info
const chatRoom = new Air('chat', {
    id: 'user_123',
    name: 'Alice'
});

// Auto-generated ID with custom name
const chatRoom = new Air('chat', { name: 'Bob' });
```

---

### Connection Methods

#### `.connect()`

Establish WebSocket connection to the server.

```javascript
air.connect();
```

**Returns:** void

**Example:**
```javascript
const air = new Air('notifications', { name: 'John' });
air.onConnect(() => {
    console.log('Ready!');
});
air.connect();
```

---

#### `.disconnect()`

Close the WebSocket connection and stop auto-reconnect.

```javascript
air.disconnect();
```

**Returns:** void

**Example:**
```javascript
// Disconnect when user logs out
logoutButton.addEventListener('click', () => {
    air.disconnect();
});
```

---

#### `.isConnected()`

Check if currently connected to the server.

```javascript
const connected = air.isConnected();
```

**Returns:** boolean

**Example:**
```javascript
if (air.isConnected()) {
    air.send({ message: 'Hello!' });
} else {
    console.log('Not connected');
}
```

---

### Messaging Methods

#### `.send(data)`

Send data to all clients in the same room (except sender).

```javascript
air.send(data);
```

**Parameters:**
- `data` (any): Data to send (string, object, array, etc.)

**Returns:** void

**Example:**
```javascript
// Send string
air.send('Hello!');

// Send object
air.send({
    message: 'Hello',
    timestamp: Date.now()
});

// Send complex data
air.send({
    text: 'Check out this image!',
    image: 'data:image/png;base64,...',
    metadata: { user: 'Alice', type: 'photo' }
});
```

---

#### `.sendTo(userId, data)`

Send direct message to a specific user.

```javascript
air.sendTo(userId, data);
```

**Parameters:**
- `userId` (string): Target user's ID
- `data` (any): Data to send

**Returns:** void

**Example:**
```javascript
// Send direct message
air.sendTo('user_456', {
    message: 'Private message!',
    encrypted: true
});

// Send direct notification
air.sendTo('user_789', {
    type: 'notification',
    title: 'New Message',
    body: 'You have a new message from Alice'
});
```

---

#### `.typing()`

Send typing indicator to other users in the room. Automatically debounced (max one per 2 seconds).

```javascript
air.typing();
```

**Returns:** void

**Example:**
```javascript
// Send typing indicator when user types
messageInput.addEventListener('input', () => {
    air.typing();
});
```

---

### User Methods

#### `.getUsers()`

Get list of current users in the room.

```javascript
const users = air.getUsers();
```

**Returns:** Array of `{ id, name }` objects

**Example:**
```javascript
const users = air.getUsers();
console.log(`${users.length} users online:`);
users.forEach(user => {
    console.log(`- ${user.name} (${user.id})`);
});
```

---

#### `.getUserCount()`

Get count of current users in the room.

```javascript
const count = air.getUserCount();
```

**Returns:** number

**Example:**
```javascript
const count = air.getUserCount();
statusLabel.textContent = `${count} user${count !== 1 ? 's' : ''} online`;
```

---

### Event Listeners

#### `.onConnect(callback)`

Called when successfully connected to the server.

```javascript
air.onConnect(callback);
```

**Callback Parameters:**
- `info` (object): Connection info
  - `room` (string): Room name
  - `id` (string): User ID
  - `name` (string): User name

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onConnect(({ room, id, name }) => {
    console.log(`Connected to ${room} as ${name}!`);
    statusIndicator.className = 'connected';
});
```

---

#### `.onMessage(callback)`

Called when a broadcast message is received.

```javascript
air.onMessage(callback);
```

**Callback Parameters:**
- `message` (object): Message object
  - `type` (string): 'message'
  - `from` (string): Sender user ID
  - `sender` (string): Sender name
  - `data` (any): Message data

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onMessage((msg) => {
    console.log(`${msg.sender} sent:`, msg.data);
    addMessageToUI(msg.sender, msg.data);
});
```

---

#### `.onDirect(callback)`

Called when a direct message is received.

```javascript
air.onDirect(callback);
```

**Callback Parameters:**
- `message` (object): Direct message object
  - `type` (string): 'direct'
  - `from` (string): Sender user ID
  - `sender` (string): Sender name
  - `data` (any): Message data

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onDirect((msg) => {
    console.log(`Private message from ${msg.sender}:`, msg.data);
    showNotification(`New DM from ${msg.sender}`);
});
```

---

#### `.onUserList(callback)`

Called when the user list is updated (user joins/leaves).

```javascript
air.onUserList(callback);
```

**Callback Parameters:**
- `users` (array): Array of user objects
  - Each user: `{ id: string, name: string }`

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onUserList((users) => {
    userCount.textContent = `${users.length} online`;

    userListElement.innerHTML = '';
    users.forEach(user => {
        const li = document.createElement('li');
        li.textContent = user.name;
        userListElement.appendChild(li);
    });
});
```

---

#### `.onJoin(callback)`

Called when a user joins the room.

```javascript
air.onJoin(callback);
```

**Callback Parameters:**
- `user` (object): User who joined
  - `id` (string): User ID
  - `name` (string): User name

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onJoin((user) => {
    console.log(`${user.name} joined the room`);
    addSystemMessage(`${user.name} joined`);
});
```

---

#### `.onLeave(callback)`

Called when a user leaves the room.

```javascript
air.onLeave(callback);
```

**Callback Parameters:**
- `user` (object): User who left
  - `id` (string): User ID
  - `name` (string): User name

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onLeave((user) => {
    console.log(`${user.name} left the room`);
    addSystemMessage(`${user.name} left`);
});
```

---

#### `.onTyping(callback)`

Called when typing indicators are updated.

```javascript
air.onTyping(callback);
```

**Callback Parameters:**
- `users` (array): Array of user names who are typing

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onTyping((users) => {
    if (users.length === 0) {
        typingIndicator.textContent = '';
    } else if (users.length === 1) {
        typingIndicator.textContent = `${users[0]} is typing...`;
    } else {
        typingIndicator.textContent = `${users[0]}, ${users[1]} and ${users.length - 2} others are typing...`;
    }
});
```

---

#### `.onDisconnect(callback)`

Called when disconnected from the server.

```javascript
air.onDisconnect(callback);
```

**Callback Parameters:**
- `info` (object): Disconnect info
  - `code` (number): Close code
  - `reason` (string): Close reason

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onDisconnect(({ code, reason }) => {
    console.log(`Disconnected: ${reason} (${code})`);
    statusIndicator.className = 'disconnected';
});
```

---

#### `.onError(callback)`

Called when an error occurs.

```javascript
air.onError(callback);
```

**Callback Parameters:**
- `error` (Error): Error object

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onError((error) => {
    console.error('Connection error:', error);
    showErrorMessage('Connection failed');
});
```

---

#### `.onSent(callback)`

Called when a message is successfully sent.

```javascript
air.onSent(callback);
```

**Callback Parameters:**
- `data` (any): The data that was sent

**Returns:** Air instance (for chaining)

**Example:**
```javascript
air.onSent((data) => {
    console.log('Message sent:', data);
    messageInput.value = '';
});
```

---

### Advanced Methods

#### `.on(event, callback)`

Register a custom event listener.

```javascript
air.on(event, callback);
```

**Parameters:**
- `event` (string): Event name
- `callback` (function): Event handler

**Returns:** void

---

#### `.off(event, callback)`

Remove an event listener.

```javascript
air.off(event, callback);
```

**Parameters:**
- `event` (string): Event name
- `callback` (function): Event handler to remove

**Returns:** void

---

## HTTP API

### POST /emit

Emit messages to a room using HTTP API (requires API token authentication).

**Endpoint:** `POST https://air.arraystory.com/emit`

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
Content-Type: application/json
```

**Request Body:**
```json
{
  "your": "data",
  "can": "be",
  "anything": true
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "room": "room-name"
}
```

**Error Responses:**

- `401 Unauthorized`: Missing or invalid API token
- `400 Bad Request`: Invalid JSON
- `404 Not Found`: Room not found or inactive
- `413 Request Entity Too Large`: Message exceeds room's buffer size limit

---

### HTTP API Examples

#### cURL

```bash
curl -X POST https://air.arraystory.com/emit \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello from server!",
    "timestamp": 1234567890,
    "priority": "high"
  }'
```

#### Node.js (axios)

```javascript
const axios = require('axios');

async function emitMessage(data) {
    try {
        const response = await axios.post('https://air.arraystory.com/emit', data, {
            headers: {
                'Authorization': `Bearer ${process.env.AIR_API_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });
        console.log('Message sent:', response.data);
    } catch (error) {
        console.error('Error:', error.response?.data || error.message);
    }
}

emitMessage({
    message: 'Server notification',
    user: 'admin',
    action: 'broadcast'
});
```

#### Node.js (fetch)

```javascript
async function emitMessage(data) {
    const response = await fetch('https://air.arraystory.com/emit', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${process.env.AIR_API_TOKEN}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    });

    const result = await response.json();
    console.log(result);
}
```

#### Python

```python
import requests
import os

def emit_message(data):
    response = requests.post(
        'https://air.arraystory.com/emit',
        json=data,
        headers={
            'Authorization': f'Bearer {os.getenv("AIR_API_TOKEN")}',
            'Content-Type': 'application/json'
        }
    )
    return response.json()

# Usage
result = emit_message({
    'message': 'Hello from Python!',
    'timestamp': 1234567890
})
print(result)
```

#### PHP

```php
<?php
$data = [
    'message' => 'Hello from PHP!',
    'timestamp' => time()
];

$options = [
    'http' => [
        'header'  => [
            "Content-Type: application/json",
            "Authorization: Bearer " . getenv('AIR_API_TOKEN')
        ],
        'method'  => 'POST',
        'content' => json_encode($data)
    ]
];

$context  = stream_context_create($options);
$result = file_get_contents('https://air.arraystory.com/emit', false, $context);
echo $result;
?>
```

---

## Authentication

### API Tokens

API tokens are required for HTTP API access. Tokens are managed in the database.

**Features:**
- Per-room access control
- Expiration dates
- Usage tracking
- Enable/disable tokens

### Managing Tokens via Database

```sql
-- Create an API token
INSERT INTO air_api_tokens (room_id, token, name, is_active, expires_at)
VALUES (
    1,
    'your-secure-token-here',
    'My App API Token',
    TRUE,
    '2025-12-31 23:59:59'
);

-- List all tokens
SELECT
    t.name,
    t.token,
    r.name as room_name,
    t.is_active,
    t.expires_at,
    t.last_used_at
FROM air_api_tokens t
JOIN air_rooms r ON t.room_id = r.id;

-- Disable a token
UPDATE air_api_tokens
SET is_active = FALSE
WHERE token = 'token-to-disable';
```

---

## Database Management

### Rooms

```sql
-- Create a new room
INSERT INTO air_rooms (name, description, max_buffer_size, is_active)
VALUES ('my-room', 'My awesome room', 32768, TRUE);

-- List all rooms
SELECT * FROM air_rooms;

-- Update room settings
UPDATE air_rooms
SET max_buffer_size = 65536
WHERE name = 'my-room';
```

### Domain Whitelist

```sql
-- Add domain to whitelist for a room
INSERT INTO air_room_domains (room_id, domain)
VALUES (1, 'example.com');

-- List whitelisted domains
SELECT r.name as room, d.domain
FROM air_room_domains d
JOIN air_rooms r ON d.room_id = r.id;

-- Remove domain from whitelist
DELETE FROM air_room_domains
WHERE room_id = 1 AND domain = 'old-domain.com';
```

---

## Code Examples

### Complete Chat Application

```html
<!DOCTYPE html>
<html>
<head>
    <title>AirSocket Chat</title>
</head>
<body>
    <div id="messages"></div>
    <div id="users"></div>
    <div id="typing"></div>
    <input type="text" id="messageInput" placeholder="Type a message...">
    <button onclick="sendMessage()">Send</button>

    <script src="https://air.arraystory.com/air.js"></script>
    <script>
        const userName = prompt('Enter your name:') || 'Anonymous';
        const air = new Air('chat', { name: userName });

        air.onConnect(() => {
            console.log('Connected!');
        })
        .onMessage((msg) => {
            addMessage(msg.sender, msg.data);
        })
        .onJoin((user) => {
            addSystemMessage(`${user.name} joined`);
        })
        .onLeave((user) => {
            addSystemMessage(`${user.name} left`);
        })
        .onUserList((users) => {
            updateUserList(users);
        })
        .onTyping((users) => {
            updateTypingIndicator(users);
        });

        air.connect();

        // Send typing indicator on input
        document.getElementById('messageInput').addEventListener('input', () => {
            air.typing();
        });

        function sendMessage() {
            const input = document.getElementById('messageInput');
            const text = input.value.trim();
            if (text && air.isConnected()) {
                air.send({ text });
                input.value = '';
            }
        }

        function addMessage(sender, data) {
            const div = document.createElement('div');
            div.textContent = `${sender}: ${data.text}`;
            document.getElementById('messages').appendChild(div);
        }

        function addSystemMessage(text) {
            const div = document.createElement('div');
            div.textContent = text;
            div.style.fontStyle = 'italic';
            div.style.color = '#999';
            document.getElementById('messages').appendChild(div);
        }

        function updateUserList(users) {
            const list = document.getElementById('users');
            list.innerHTML = `<strong>${users.length} online:</strong><br>`;
            users.forEach(user => {
                list.innerHTML += `${user.name}<br>`;
            });
        }

        function updateTypingIndicator(users) {
            const indicator = document.getElementById('typing');
            if (users.length === 0) {
                indicator.textContent = '';
            } else if (users.length === 1) {
                indicator.textContent = `${users[0]} is typing...`;
            } else {
                indicator.textContent = `${users[0]} and ${users.length - 1} others are typing...`;
            }
        }
    </script>
</body>
</html>
```

### Real-time Notifications

```javascript
const notifications = new Air('user-notifications-123', {
    name: 'User#123'
});

notifications.onConnect(() => {
    console.log('Listening for notifications...');
})
.onMessage((msg) => {
    showNotification(msg.data.title, msg.data.message);
})
.onDirect((msg) => {
    // Private notification
    showPrivateNotification(msg.data);
});

notifications.connect();

function showNotification(title, message) {
    if ('Notification' in window && Notification.permission === 'granted') {
        new Notification(title, { body: message });
    }
}
```

### Live Dashboard Updates

```javascript
const dashboard = new Air('dashboard', {
    id: 'admin',
    name: 'Admin User'
});

dashboard.onConnect(() => {
    console.log('Dashboard connected');
})
.onMessage((msg) => {
    updateDashboard(msg.data);
});

dashboard.connect();

function updateDashboard(data) {
    if (data.type === 'stats') {
        document.getElementById('users').textContent = data.users;
        document.getElementById('revenue').textContent = data.revenue;
    }
}
```

### Direct Messaging

```javascript
const chat = new Air('private-chat', {
    id: 'user_alice',
    name: 'Alice'
});

chat.onConnect(() => {
    console.log('Connected');
})
.onMessage((msg) => {
    // Public message
    console.log('Public:', msg.data);
})
.onDirect((msg) => {
    // Private message
    console.log(`DM from ${msg.sender}:`, msg.data);
    addPrivateMessage(msg.sender, msg.data);
});

chat.connect();

// Send private message to Bob
function sendPrivateMessage(message) {
    chat.sendTo('user_bob', { text: message, encrypted: true });
}

// Send public message to everyone
function sendPublicMessage(message) {
    chat.send({ text: message });
}
```

---

## Best Practices

### Message Size Limits

- Default max message size: **32KB** per room
- Configurable per room in database (`max_buffer_size`)
- Keep messages small for better performance
- For large data, consider storing elsewhere and sending references

### Connection Limits

- Air supports thousands of concurrent connections
- Consider load balancing for very large deployments
- Use rooms to segment users and reduce broadcast overhead

### Security

- **Always use domain whitelist** for WebSocket connections
- **Use HTTPS/WSS** in production
- **Rotate API tokens** regularly
- **Never expose API tokens** in client-side code
- **Validate all data** on both client and server

### Performance Tips

- Use typing indicators sparingly (already debounced)
- Batch updates when possible
- Use direct messages for private communication
- Clean up event listeners when no longer needed
- Monitor message sizes and frequency

### Do's and Don'ts

**✅ DO:**
- Use domain whitelist for security
- Implement reconnection logic (built-in)
- Validate all incoming data
- Use typed messages for different actions
- Monitor connection status

**❌ DON'T:**
- Don't send sensitive data without encryption
- Don't send messages too frequently (rate limiting recommended)
- Don't store large files in messages
- Don't trust client-side data without validation
- Don't forget to handle disconnection

---

## Troubleshooting

### Connection Issues

**Problem:** WebSocket fails to connect

**Solutions:**
1. Check domain is whitelisted in database
2. Verify room exists and is active
3. Ensure using WSS (not WS) in production
4. Check firewall/proxy settings
5. Verify server is running

### Message Not Received

**Problem:** Messages not appearing for other users

**Solutions:**
1. Check `isConnected()` before sending
2. Verify room name matches
3. Check message size doesn't exceed limit
4. Ensure recipient is in same room
5. Check browser console for errors

### Typing Indicators Not Working

**Problem:** Typing indicators not showing

**Solutions:**
1. Ensure `onTyping()` listener is registered
2. Check that `typing()` is being called
3. Verify multiple users are in the room
4. Check network connectivity

---

## Rate Limits

Current implementation has no hard rate limits, but consider implementing:

- **Messages**: ~10 per second per user
- **Typing indicators**: Auto-limited to 1 per 2 seconds
- **Connections**: No limit (monitor server resources)

---

## Support

For issues or questions:
- Visit: https://arraystory.com/air
- GitHub: https://github.com/arraystory/air

---

**AirSocket** - Less than 1KB, infinite possibilities.
Built by ArrayStory.
