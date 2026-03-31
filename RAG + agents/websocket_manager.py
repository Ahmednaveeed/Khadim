from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.active_connections: dict = {}  # key: room_name (str), value: list of WebSocket

    async def connect(self, websocket: WebSocket, room: str):
        await websocket.accept()
        self.active_connections.setdefault(room, []).append(websocket)

    def disconnect(self, websocket: WebSocket, room: str):
        if room in self.active_connections:
            self.active_connections[room].remove(websocket)

    async def broadcast(self, room: str, message: dict):
        for ws in self.active_connections.get(room, []):
            try:
                await ws.send_json(message)
            except Exception:
                pass


manager = ConnectionManager()