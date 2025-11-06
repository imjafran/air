Project Requirements (Simple Realtime Room Bridge)
1) Purpose

A lightweight realtime messaging bridge that allows multiple web clients to join a named room and exchange messages instantly.

2) Roles

Client (Browser JS): connects to a room, sends & receives messages.

Server: manages rooms and delivery of messages.

External API Caller: can push messages into any room.

3) Core Features
Feature	Description
Create/Join Room	When a client connects with a room name, the room is created if it doesn't exist, then the client is added to that room.
Broadcast Messaging	Messages sent by any client should be delivered to all other clients in the same room.
External Emit API	An HTTP API endpoint should allow sending a message to a specific room (server-to-clients broadcast).
Auto Room Lifecycle	If no clients remain in a room, that room may be safely removed from memory.
4) Client Behavior Requirements

Client connects using a room name parameter.

Client should automatically attempt reconnection if disconnected.

Client displays a connection status (Connecting → Connected → Disconnected → Reconnecting).

Client can send message events.

Client should render received messages in a visible list.

5) Protocol and Format
Aspect	Requirement
Transport	WebSocket
Client → Server Message Format	JSON object
Server → Client Broadcast Format	Same JSON structure as sent
External Emit API Request Format	JSON object containing room and data
6) Message Handling Rules

The server does not inspect or modify message contents.

The server simply forwards data as-is to all clients in the same room.

Messages are not persisted and not stored for later retrieval.

7) Scoping & Limits
Category	Scope
Authentication	Not required at this stage
Authorization	Not required
History Storage	No message logging or saving
Persistence	None — rooms live in memory only
Scaling	Single server instance only (no clustering yet)
8) Operational Requirements

System must run locally without SSL for development.

Must support multiple browser tabs as separate clients.

Must handle typical send/receive round-trip with minimal latency.

9) Success Criteria
Scenario	Expected Outcome
Two clients join the same room	Both receive each other's messages
Client disconnects	Room updates membership accordingly
No clients left in a room	Room is removed automatically
External API sends message	All clients in the specified room receive it instantly
10) Future Extension Considerations (Not part of current scope)

Horizontal scaling with Redis pub/sub

Token-based room access

Message persistence for chat history

Presence indicators (e.g., "user joined / left")