# server.py
import asyncio
import json
import time
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import uvicorn
import pyautogui
from typing import Optional

# =============================
# PyAutoGUI Optimizations
# =============================
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0  # remove built-in delay

# sensitivity factor for mouse movement
SENSITIVITY = 3.0  
# throttle updates to ~60fps
FRAME_INTERVAL = 0.016  

app = FastAPI()

class ConnectionManager:
    def __init__(self):
        self.websocket: Optional[WebSocket] = None

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.websocket = websocket

    def disconnect(self):
        self.websocket = None

    async def recv(self):
        if not self.websocket:
            return None
        try:
            data = await self.websocket.receive_text()
            return data
        except WebSocketDisconnect:
            self.disconnect()
            return None
        except Exception:
            return None

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    print("Client connected:", websocket.client)

    last_move = time.time()

    try:
        while True:
            text = await manager.recv()
            if text is None:
                print("Client disconnected")
                break

            try:
                msg = json.loads(text)
            except Exception:
                continue

            mtype = msg.get("type")
            if mtype == "move":
                dx = float(msg.get("dx", 0.0))
                dy = float(msg.get("dy", 0.0))
                now = time.time()
                # throttle to ~60 fps
                if now - last_move >= FRAME_INTERVAL:
                    pyautogui.moveRel(dx * SENSITIVITY, dy * SENSITIVITY, duration=0)
                    last_move = now

            elif mtype == "click":
                button = msg.get("button", "left")
                down = bool(msg.get("down", False))
                try:
                    if down:
                        pyautogui.mouseDown(button=button)
                    else:
                        pyautogui.mouseUp(button=button)
                except Exception:
                    pass

            elif mtype == "scroll":
                amt = int(msg.get("amount", 0))
                pyautogui.scroll(amt)

            elif mtype == "ping":
                await websocket.send_text('{"type":"pong"}')

    except WebSocketDisconnect:
        manager.disconnect()
        print("Websocket disconnected")
    except Exception as e:
        manager.disconnect()
        print("Error:", e)
    finally:
        manager.disconnect()

if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=8000, log_level="info")
