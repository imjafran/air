/**
 * Air - Real-time WebSocket client for ArrayStory
 *
 * Usage:
 * const air = new Air('room1');
 * air.onMessage((data) => console.log(data));
 * air.send('hello');
 * air.connect();
 */

class Air {
    constructor(room) {
        this.serverUrl = 'ws://localhost:8282';
        this.room = room;
        this.ws = null;
        this.listeners = {};
        this.reconnectInterval = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 10;
        this.reconnectDelay = 3000;
    }

    /**
     * Connect to the WebSocket server
     */
    connect() {
        const wsUrl = `${this.serverUrl}/ws?channel=${encodeURIComponent(this.room)}`;

        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            this.reconnectAttempts = 0;
            if (this.reconnectInterval) {
                clearInterval(this.reconnectInterval);
                this.reconnectInterval = null;
            }
            this._emit('connect', { room: this.room });
        };

        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this._emit('message', data);
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
     * @param {function} callback - Callback function
     */
    onMessage(callback) {
        this.on('message', callback);
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
     * Send message to current room
     * @param {*} data - Data to send (string, object, array, etc)
     */
    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            const payload = {
                channel: this.room,
                data: data
            };
            this.ws.send(JSON.stringify(payload));
            this._emit('sent', data);
        }
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
