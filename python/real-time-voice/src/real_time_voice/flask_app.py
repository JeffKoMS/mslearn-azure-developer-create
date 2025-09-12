from __future__ import annotations

from pathlib import Path
import threading
import asyncio
import time
import logging
import traceback
from typing import Optional, Tuple, Union, cast, List, Dict, Any
import queue
import json
import base64

from flask import Flask, render_template, jsonify, Response, request

###############################################################################
# NOTE: This file now contains a self-contained implementation of the voice
# assistant (no dependency on voice_console.py). It embeds a minimal
# AudioProcessor and BasicVoiceAssistant suitable for the web demo.
###############################################################################

app = Flask(__name__, template_folder=str(Path(__file__).parent / "templates"))

# ------------------------------
# Global assistant state
# ------------------------------
state_lock = threading.Lock()
assistant_state = {
    "state": "idle",  # idle|starting|ready|listening|processing|assistant_speaking|error|stopped
    "message": "Click Start to begin a voice session.",
    "last_error": None,
    "connected": False,
}
assistant_thread: Optional[threading.Thread] = None
assistant_instance = None  # Populated with a running assistant instance
assistant_loop: Optional[asyncio.AbstractEventLoop] = None
shutdown_requested = False

# SSE client management: each client owns a queue we push events into
_sse_clients: List["queue.Queue[str]"] = []
_sse_clients_lock = threading.Lock()


def _broadcast(event: Dict[str, Any]):
    data = f"data: {json.dumps(event)}\n\n"
    with _sse_clients_lock:
        dead = []
        for q in _sse_clients:
            try:
                q.put_nowait(data)
            except Exception:
                dead.append(q)
        for d in dead:
            _sse_clients.remove(d)


def set_state(state: str, message: str, *, error: str | None = None):
    with state_lock:
        assistant_state["state"] = state
        assistant_state["message"] = message
        if error:
            assistant_state["last_error"] = error
        if state in {"ready", "listening", "processing", "assistant_speaking"}:
            assistant_state["connected"] = True
        if state in {"error", "stopped", "idle"}:
            # Do not forcibly clear connected True if error occurs after connection, unless never reached ready
            if state != "error":
                assistant_state["connected"] = False
    _broadcast({
        "type": "status",
        "state": assistant_state["state"],
        "message": assistant_state["message"],
        "last_error": assistant_state.get("last_error"),
        "connected": assistant_state.get("connected"),
    })


# Basic logging (can be overridden by parent app)
logger = logging.getLogger("real_time_voice.flask")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] %(levelname)s in %(name)s: %(message)s")


def _validate_env() -> Tuple[bool, str]:
    """Validate required environment variables before starting assistant."""
    import os

    model = os.environ.get("VOICE_LIVE_MODEL")
    voice = os.environ.get("VOICE_LIVE_VOICE")
    api_key = os.environ.get("AZURE_VOICE_LIVE_API_KEY")

    missing = []
    if not model:
        missing.append("VOICE_LIVE_MODEL")
    if not voice:
        missing.append("VOICE_LIVE_VOICE")
    if not api_key:
        # Not strictly required if DefaultAzureCredential works, but warn user
        logger.info("AZURE_VOICE_LIVE_API_KEY not set; will attempt DefaultAzureCredential")

    if missing:
        return False, f"Missing required environment variables: {', '.join(missing)}"
    return True, "ok"


class AudioProcessor:  # Retained for interface clarity; no-op since browser handles audio
    async def start_capture(self):  # pragma: no cover - no-op
        return
    async def stop_capture(self):  # pragma: no cover - no-op
        return
    async def start_playback(self):  # pragma: no cover - no-op
        return
    async def queue_audio(self, data: bytes):  # pragma: no cover - no-op
        return
    async def stop_playback(self):  # pragma: no cover - no-op
        return
    async def cleanup(self):  # pragma: no cover - no-op
        return


class BasicVoiceAssistant:
    """Minimal assistant implementation for VoiceLive API."""

    def __init__(
        self,
        endpoint: str,
        credential,
        model: str,
        voice: str,
        instructions: str,
        state_callback=None,
    ):
        self.endpoint = endpoint
        self.credential = credential
        self.model = model
        self.voice = voice
        self.instructions = instructions
        self.connection = None
        self.audio: Optional[AudioProcessor] = AudioProcessor()
        self._stopping = False
        self.state_callback = state_callback or (lambda *_: None)

    async def start(self):
        from azure.ai.voicelive.aio import connect  # type: ignore
        from azure.ai.voicelive.models import (
            RequestSession,
            ServerVad,
            AzureStandardVoice,
            Modality,
            AudioFormat,
        )  # type: ignore
        verbose = bool(int((__import__('os').environ.get('VOICE_LIVE_VERBOSE') or '0') != '0')) if False else bool(__import__('os').environ.get('VOICE_LIVE_VERBOSE'))
        try:
            _broadcast({"type": "log", "level": "info", "msg": f"Connecting to VoiceLive endpoint={self.endpoint} model={self.model} voice={self.voice}"})
            async with connect(
                endpoint=self.endpoint,
                credential=self.credential,
                model=self.model,
                connection_options={"max_msg_size": 10 * 1024 * 1024, "heartbeat": 20, "timeout": 20},
            ) as conn:
                self.connection = conn

                # Determine voice config
                if self.voice.startswith("en-") or "-" in self.voice:
                    voice_cfg: Union[str, AzureStandardVoice] = AzureStandardVoice(name=self.voice, type="azure-standard")
                else:
                    voice_cfg = self.voice

                session_config = RequestSession(
                    modalities=[Modality.TEXT, Modality.AUDIO],
                    instructions=self.instructions,
                    voice=voice_cfg,
                    input_audio_format=AudioFormat.PCM16,
                    output_audio_format=AudioFormat.PCM16,
                    turn_detection=ServerVad(threshold=0.5, prefix_padding_ms=300, silence_duration_ms=500),
                )
                await conn.session.update(session=session_config)

                # Event loop
                from azure.ai.voicelive.models import ServerEventType  # type: ignore
                async for event in conn:
                    if self._stopping:
                        break
                    et = event.type
                    if verbose:
                        _broadcast({"type": "log", "level": "debug", "event_type": et})
                    if et == ServerEventType.SESSION_UPDATED:
                        # Inform user they can begin speaking immediately; "Listening" event may only appear once VAD detects speech
                        self.state_callback("ready", "Session ready. You can start speaking now.")
                    elif et == ServerEventType.INPUT_AUDIO_BUFFER_SPEECH_STARTED:
                        self.state_callback("listening", "Listening… speak now")
                        try:
                            await conn.response.cancel()
                        except Exception:
                            pass
                    elif et == ServerEventType.INPUT_AUDIO_BUFFER_SPEECH_STOPPED:
                        self.state_callback("processing", "Processing your input…")
                    elif et == ServerEventType.RESPONSE_AUDIO_DELTA:  # type: ignore[attr-defined]
                        if assistant_state.get("state") != "assistant_speaking":
                            self.state_callback("assistant_speaking", "Assistant speaking…")
                        data = getattr(event, "delta", None)
                        if data:
                            _broadcast({"type": "audio", "audio": base64.b64encode(data).decode("utf-8")})
                    elif et == ServerEventType.RESPONSE_AUDIO_DONE:
                        self.state_callback("ready", "Assistant finished. You can speak again.")
                    elif et == ServerEventType.RESPONSE_DONE:
                        if assistant_state.get("state") not in {"error", "ready", "listening"}:
                            self.state_callback("ready", "Assistant ready for next input.")
                    elif et == ServerEventType.ERROR:  # type: ignore[attr-defined]
                        err = getattr(event, "error", None)
                        msg = getattr(err, "message", "Unknown error") if err else "Unknown error"
                        self.state_callback("error", f"Error: {msg}")
                    # Additional events ignored for brevity
        except Exception as e:
            tb = traceback.format_exc(limit=6)
            _broadcast({"type": "log", "level": "error", "msg": f"Connection failed: {e}", "trace": tb})
            self.state_callback("error", f"Connection failed: {e}")
            return

        # Cleanup (no local audio resources now)
        self.connection = None

    async def append_audio(self, audio_b64: str):
        if not self.connection:
            return
        try:
            await self.connection.input_audio_buffer.append(audio=audio_b64)
        except Exception as e:  # pragma: no cover
            logger.error("Failed to append audio: %s", e)

    def request_stop(self):
        self._stopping = True


def _run_assistant_bg():
    """Background thread target to run the async assistant until completion."""
    global assistant_instance, shutdown_requested, assistant_loop
    try:
        import os
        from azure.core.credentials import AzureKeyCredential, TokenCredential  # type: ignore
        from azure.identity import DefaultAzureCredential  # type: ignore

        api_key = os.environ.get("AZURE_VOICE_LIVE_API_KEY")
        endpoint = os.environ.get("AZURE_VOICE_LIVE_ENDPOINT", "wss://api.voicelive.com/v1")
        model = os.environ.get("VOICE_LIVE_MODEL")
        voice = os.environ.get("VOICE_LIVE_VOICE")
        instructions = os.environ.get("VOICE_LIVE_INSTRUCTIONS") or "You are a helpful voice assistant."

        if not model or not voice:
            set_state("error", "VOICE_LIVE_MODEL / VOICE_LIVE_VOICE env vars must be set")
            return

        if api_key:
            credential: Union[TokenCredential, AzureKeyCredential] = AzureKeyCredential(api_key)
        else:
            credential = DefaultAzureCredential()

        def cb(state, message):
            set_state(state, message)

        assistant_instance = BasicVoiceAssistant(
            endpoint=endpoint,
            credential=credential,
            model=model,
            voice=voice,
            instructions=instructions,
            state_callback=cb,
        )
        assistant_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(assistant_loop)
        assistant_loop.run_until_complete(assistant_instance.start())
        set_state("stopped", "Session ended.")
    except Exception as e:  # pragma: no cover - runtime safety
        tb = traceback.format_exc(limit=6)
        logger.error("Assistant crashed: %s\n%s", e, tb)
        set_state("error", f"Assistant crashed: {e}", error=tb)
    finally:
        try:
            if assistant_loop and assistant_loop.is_running():
                assistant_loop.stop()
        except Exception:
            pass


@app.post("/start-session")
def start_session():
    global assistant_thread
    with state_lock:
        if assistant_state["state"] in {"starting", "ready", "listening", "processing", "assistant_speaking"}:
            return jsonify({"started": False, "status": assistant_state})

    ok, msg = _validate_env()
    if not ok:
        set_state("error", msg, error=msg)
        return jsonify({"started": False, "status": assistant_state}), 400

    with state_lock:
        assistant_state["state"] = "starting"
        assistant_state["message"] = "Starting voice session…"
        assistant_state["last_error"] = None
        assistant_state["connected"] = False

    assistant_thread = threading.Thread(target=_run_assistant_bg, daemon=True)
    assistant_thread.start()
    # Give the thread a brief moment to progress
    time.sleep(0.1)
    return jsonify({"started": True, "status": assistant_state})


@app.post("/stop-session")
def stop_session():
    global assistant_instance
    if not assistant_instance:
        return jsonify({"stopped": False, "reason": "No active session"}), 400
    assistant_instance.request_stop()
    set_state("stopped", "Stopping session…")
    return jsonify({"stopped": True})


@app.post("/audio-chunk")
def audio_chunk():
    """Receive base64 PCM16 (24kHz mono) audio from browser."""
    global assistant_instance, assistant_loop
    if not assistant_instance or not assistant_loop:
        return jsonify({"accepted": False, "reason": "No active session"}), 400
    try:
        payload = request.get_json(silent=True) or {}
        audio_b64 = payload.get("audio")
        if not audio_b64:
            return jsonify({"accepted": False, "reason": "Missing audio field"}), 400
        # Schedule append inside assistant loop
        inst = assistant_instance
        if not inst:
            return jsonify({"accepted": False, "reason": "Assistant not ready"}), 503
        def _task():
            return asyncio.create_task(inst.append_audio(audio_b64))
        assistant_loop.call_soon_threadsafe(_task)
        return jsonify({"accepted": True})
    except Exception as e:  # pragma: no cover
        return jsonify({"accepted": False, "reason": str(e)}), 500


@app.get("/events")
def sse_events():
    """Server-Sent Events stream for status + audio."""
    q: "queue.Queue[str]" = queue.Queue()
    with _sse_clients_lock:
        _sse_clients.append(q)

    # Send current state immediately
    q.put_nowait(
        "data: "
        + json.dumps(
            {
                "type": "status",
                "state": assistant_state["state"],
                "message": assistant_state["message"],
                "last_error": assistant_state.get("last_error"),
                "connected": assistant_state.get("connected"),
            }
        )
        + "\n\n"
    )

    def gen():
        try:
            while True:
                msg = q.get()
                yield msg
        except GeneratorExit:  # client disconnected
            with _sse_clients_lock:
                if q in _sse_clients:
                    _sse_clients.remove(q)

    return Response(gen(), mimetype="text/event-stream")


@app.get("/status")
def status():
    with state_lock:
        return jsonify(assistant_state)


@app.get("/health")
def health():
    with state_lock:
        return jsonify({
            "ok": assistant_state.get("state") not in {"error"},
            "state": assistant_state.get("state"),
            "connected": assistant_state.get("connected"),
            "has_connection_obj": bool(assistant_instance and getattr(assistant_instance, 'connection', None)),
        }), 200


@app.route("/")
def index():
    return render_template("index.html")


def main() -> None:
    # Basic dev server; in production consider a WSGI/ASGI server like gunicorn or uvicorn.
    app.run(host="127.0.0.1", port=5000, debug=True)


if __name__ == "__main__":  # pragma: no cover
    main()
