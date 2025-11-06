/**
 * Air - Real-time WebSocket client for ArrayStory
 *
 * Usage:
 * const air = new Air('room1', { id: 'user123', name: 'John' });
 * air.onMessage((data) => console.log(data));
 * air.send('hello');
 * air.connect();
 */

class Air {
    constructor(room, options = {}) {
        this.serverUrl = 'wss://air.arraystory.com';
        this.room = room;
        this.id = options.id || this._generateId();
        this.name = options.name || 'Anonymous';
        this.ws = null;
        this.listeners = {};
        this.reconnectInterval = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 10;
        this.reconnectDelay = 3000;
        this.users = [];
        this.typingUsers = new Set();
        this.typingTimeout = null;
    }

    _generateId() {
        return 'user_' + Math.random().toString(36).substr(2, 9) + Date.now().toString(36);
    }

    /**
     * Connect to the WebSocket server
     */
    connect() {
        const wsUrl = `${this.serverUrl}/ws?channel=${encodeURIComponent(this.room)}&id=${encodeURIComponent(this.id)}&name=${encodeURIComponent(this.name)}`;

        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            this.reconnectAttempts = 0;
            if (this.reconnectInterval) {
                clearInterval(this.reconnectInterval);
                this.reconnectInterval = null;
            }
            this._emit('connect', { room: this.room, id: this.id, name: this.name });
        };

        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);

                // Handle different message types
                switch (data.type) {
                    case 'message':
                        this._emit('message', data);
                        break;
                    case 'direct':
                        this._emit('direct', data);
                        break;
                    case 'typing':
                        this._handleTyping(data);
                        break;
                    case 'userlist':
                        this.users = data.users || [];
                        this._emit('userlist', this.users);
                        break;
                    case 'join':
                        this._emit('join', { id: data.from, name: data.sender });
                        break;
                    case 'leave':
                        this._emit('leave', { id: data.from, name: data.sender });
                        break;
                    default:
                        this._emit('message', data);
                }
            } catch (e) {
                this._emit('message', event.data);
            }
        };

        this.ws.onerror = (error) => {
            this._emit('error', error);
        };

        this.ws.onclose = (event) => {
            this._emit('disconnect', { code: event.code, reason: event.reason });

            // Auto-reconnect
            if (this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectAttempts++;
                this.reconnectInterval = setTimeout(() => this.connect(), this.reconnectDelay);
            }
        };
    }

    _handleTyping(data) {
        if (data.from === this.id) return; // Ignore own typing

        this.typingUsers.add(data.sender);
        this._emit('typing', Array.from(this.typingUsers));

        // Clear typing after 3 seconds
        setTimeout(() => {
            this.typingUsers.delete(data.sender);
            this._emit('typing', Array.from(this.typingUsers));
        }, 3000);
    }

    /**
     * Register connect event listener
     * @param {function} callback - Callback function
     */
    onConnect(callback) {
        this.on('connect', callback);
        return this;
    }

    /**
     * Register message event listener
     * @param {function} callback - Callback function receiving { type, from, sender, data }
     */
    onMessage(callback) {
        this.on('message', callback);
        return this;
    }

    /**
     * Register direct message event listener
     * @param {function} callback - Callback function receiving { type, from, sender, data }
     */
    onDirect(callback) {
        this.on('direct', callback);
        return this;
    }

    /**
     * Register user list update event listener
     * @param {function} callback - Callback function receiving array of { id, name }
     */
    onUserList(callback) {
        this.on('userlist', callback);
        return this;
    }

    /**
     * Register user join event listener
     * @param {function} callback - Callback function receiving { id, name }
     */
    onJoin(callback) {
        this.on('join', callback);
        return this;
    }

    /**
     * Register user leave event listener
     * @param {function} callback - Callback function receiving { id, name }
     */
    onLeave(callback) {
        this.on('leave', callback);
        return this;
    }

    /**
     * Register typing indicator event listener
     * @param {function} callback - Callback function receiving array of typing user names
     */
    onTyping(callback) {
        this.on('typing', callback);
        return this;
    }

    /**
     * Register disconnect event listener
     * @param {function} callback - Callback function
     */
    onDisconnect(callback) {
        this.on('disconnect', callback);
        return this;
    }

    /**
     * Register error event listener
     * @param {function} callback - Callback function
     */
    onError(callback) {
        this.on('error', callback);
        return this;
    }

    /**
     * Register sent event listener
     * @param {function} callback - Callback function
     */
    onSent(callback) {
        this.on('sent', callback);
        return this;
    }

    /**
     * Send message to current room (broadcast to all)
     * @param {*} data - Data to send (string, object, array, etc)
     */
    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            const payload = {
                channel: this.room,
                type: 'message',
                data: data
            };
            this.ws.send(JSON.stringify(payload));
            this._emit('sent', data);
        }
    }

    /**
     * Send direct message to specific user
     * @param {string} userId - Target user ID
     * @param {*} data - Data to send
     */
    sendTo(userId, data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            const payload = {
                channel: this.room,
                type: 'direct',
                to: userId,
                data: data
            };
            this.ws.send(JSON.stringify(payload));
            this._emit('sent', { to: userId, data: data });
        }
    }

    /**
     * Send typing indicator to other users
     */
    typing() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            // Debounce typing indicator
            if (this.typingTimeout) {
                clearTimeout(this.typingTimeout);
            }

            const payload = {
                channel: this.room,
                type: 'typing'
            };
            this.ws.send(JSON.stringify(payload));

            // Don't send typing again for 2 seconds
            this.typingTimeout = setTimeout(() => {
                this.typingTimeout = null;
            }, 2000);
        }
    }

    /**
     * Get list of current users in the room
     * @returns {Array} Array of { id, name } objects
     */
    getUsers() {
        return this.users;
    }

    /**
     * Get count of current users in the room
     * @returns {number} Number of users
     */
    getUserCount() {
        return this.users.length;
    }

    /**
     * Register event listener
     * @param {string} event - Event name (connect, message, error, disconnect, sent)
     * @param {function} callback - Callback function
     */
    on(event, callback) {
        if (!this.listeners[event]) {
            this.listeners[event] = [];
        }
        this.listeners[event].push(callback);
    }

    /**
     * Remove event listener
     * @param {string} event - Event name
     * @param {function} callback - Callback function
     */
    off(event, callback) {
        if (this.listeners[event]) {
            this.listeners[event] = this.listeners[event].filter(cb => cb !== callback);
        }
    }

    /**
     * Disconnect from server
     */
    disconnect() {
        if (this.reconnectInterval) {
            clearInterval(this.reconnectInterval);
            this.reconnectInterval = null;
        }
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }

    /**
     * Check if connected
     */
    isConnected() {
        return this.ws && this.ws.readyState === WebSocket.OPEN;
    }

    /**
     * Internal: emit events to listeners
     */
    _emit(event, data) {
        if (this.listeners[event]) {
            this.listeners[event].forEach(callback => {
                try {
                    callback(data);
                } catch (e) {
                    console.error(`Error in ${event} listener:`, e);
                }
            });
        }
    }
}

// Export for use in modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Air;
}

// Also export as RealtimeClient for backwards compatibility
if (typeof window !== 'undefined') {
    window.RealtimeClient = Air;
}
