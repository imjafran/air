# Buraq - JavaScript WebSocket Client

A simple, event-driven WebSocket client for real-time communication with the Go server.

## Installation

Include the client library in your HTML:

```html
<script src="realtime-client.js"></script>
```

## Basic Usage

### Create a client instance

```javascript
const buraq = new Buraq('ws://localhost:8181', 'room1');
```

### Connect to the server

```javascript
buraq.connect();
```

### Listen to events - Method 1: Using convenience methods

```javascript
buraq
    .onConnect((data) => {
        console.log('Connected to room:', data.room);
    })
    .onMessage((data) => {
        console.log('Received:', data);
    })
    .onSent((data) => {
        console.log('Message sent:', data);
    })
    .onError((error) => {
        console.error('Error:', error);
    })
    .onDisconnect((data) => {
        console.log('Disconnected. Code:', data.code);
    });
```

### Listen to events - Method 2: Using .on()

```javascript
// When connected
buraq.on('connect', (data) => {
    console.log('Connected to room:', data.room);
});

// When receiving messages
buraq.on('message', (data) => {
    console.log('Received:', data);
});

// When message is sent
buraq.on('sent', (data) => {
    console.log('Message sent:', data);
});

// On error
buraq.on('error', (error) => {
    console.error('Error:', error);
});

// When disconnected
buraq.on('disconnect', (data) => {
    console.log('Disconnected. Code:', data.code);
});
```

### Send messages

```javascript
// Send any data type
buraq.send('Hello World');
buraq.send({ msg: 'Hello', id: 123 });
buraq.send([1, 2, 3]);
buraq.send(true);
```

### Remove event listener

```javascript
const handler = (data) => console.log(data);
buraq.on('message', handler);
buraq.off('message', handler);
```

### Check connection status

```javascript
if (buraq.isConnected()) {
    console.log('Connected');
}
```

### Disconnect

```javascript
buraq.disconnect();
```

## API Reference

### Constructor

```javascript
new Buraq(serverUrl, room)
```

- `serverUrl` (string): WebSocket server URL (e.g., 'ws://localhost:8181')
- `room` (string): Room name to join

### Methods

#### `connect()`
Establishes WebSocket connection to server.

#### `send(data)`
Sends data to the room.
- `data`: Any type (string, object, array, number, boolean)

#### `on(event, callback)`
Registers event listener.
- `event` (string): 'connect', 'message', 'sent', 'error', 'disconnect'
- `callback` (function): Handler function
- Returns: `this` (for chaining)

#### `onConnect(callback)`
Convenience method to register connect listener.
- Returns: `this` (for chaining)

#### `onMessage(callback)`
Convenience method to register message listener.
- Returns: `this` (for chaining)

#### `onDisconnect(callback)`
Convenience method to register disconnect listener.
- Returns: `this` (for chaining)

#### `onError(callback)`
Convenience method to register error listener.
- Returns: `this` (for chaining)

#### `onSent(callback)`
Convenience method to register sent listener.
- Returns: `this` (for chaining)

#### `off(event, callback)`
Removes event listener.

#### `disconnect()`
Disconnects from server and stops auto-reconnection.

#### `isConnected()`
Returns boolean indicating connection status.

## Events

### `connect`
Fired when successfully connected to room.
```javascript
buraq.onConnect((data) => {
    // data.room - current room
});
```

### `message`
Fired when receiving a message from other clients.
```javascript
buraq.onMessage((data) => {
    // data - the message content
});
```

### `sent`
Fired after successfully sending a message.
```javascript
buraq.onSent((data) => {
    // data - what was sent
});
```

### `error`
Fired on WebSocket error.
```javascript
buraq.onError((error) => {
    // error - error object
});
```

### `disconnect`
Fired when disconnected from server.
```javascript
buraq.onDisconnect((data) => {
    // data.code - close code
    // data.reason - close reason
});
```

## Auto-Reconnection

The client automatically attempts to reconnect if connection is lost.
- Max attempts: 10
- Delay: 3 seconds between attempts

Reconnection stops when:
- Max attempts reached
- Manual `disconnect()` is called

## Examples

### Simple chat (Fluent API)

```javascript
const buraq = new Buraq('ws://localhost:8181', 'chat');

buraq
    .onConnect(() => console.log('Ready to chat'))
    .onMessage((msg) => console.log('User:', msg))
    .onSent((msg) => console.log('You:', msg));

document.getElementById('send').addEventListener('click', () => {
    const text = document.getElementById('input').value;
    buraq.send(text);
});

buraq.connect();
```

### Real-time notifications

```javascript
const notifications = new Buraq('ws://localhost:8181', 'notifications');

notifications.onMessage((notification) => {
    alert(notification.title + ': ' + notification.body);
});

notifications.connect();
```

### Multi-room

```javascript
const chatRoom = new Buraq('ws://localhost:8181', 'chat-room-1');
const notifications = new Buraq('ws://localhost:8181', 'notifications');

chatRoom
    .onMessage((msg) => console.log('Chat:', msg))
    .connect();

notifications
    .onMessage((notif) => console.log('Alert:', notif))
    .connect();
```

## Browser Compatibility

Works in all modern browsers that support WebSockets:
- Chrome 16+
- Firefox 11+
- Safari 7+
- Edge (all versions)
- Opera 12.1+
