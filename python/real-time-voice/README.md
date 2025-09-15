## Real-Time Voice

Minimal project scaffold with a simple Flask single-page application.

### Installation (using uv)

```bash
uv sync
```

Or using pip in editable mode:

```bash
pip install -e .
```

### Run the CLI demo

Preferred short script name (after install / sync):

```bash
uv run console
```

Or directly as an installed script if the environment's bin is on PATH:

```bash
console
```

Legacy (still present if you kept commented lines removed): `real-time-voice`.

### Run the Flask dev server

Short name via uv:

```bash
uv run web
```

Or installed script directly:

```bash
web
```

Legacy (if retained): `real-time-voice-web`.

Or via the module path:

```bash
python -m real_time_voice.flask_app
```

Then open http://127.0.0.1:5000/ in your browser.

### Development Notes

* CLI entry: `src/real_time_voice/voice_console.py` (renamed from `cli.py`; hyphens aren't valid in module names so we use an underscore).
* Flask app: `src/real_time_voice/flask_app.py`.
* Templates: `src/real_time_voice/templates/`.
* Package now includes an `__init__.py` so build tooling (hatchling) can auto-detect the package; it exposes `__version__`.
* For production deployments consider using a production WSGI/ASGI server (e.g. gunicorn + gevent or uvicorn with an ASGI framework) and disabling `debug=True`.

### Authentication

This project now exclusively uses `DefaultAzureCredential` from `azure-identity` for authenticating with the Voice Live service. The environment variable `AZURE_VOICE_LIVE_API_KEY` has been removed. Ensure one of the supported credential sources is available in your environment (e.g. Azure CLI login, Managed Identity, Visual Studio Code Azure sign-in, environment variables for a service principal, etc.).

Required environment variables at runtime:

* `VOICE_LIVE_MODEL`
* `VOICE_LIVE_VOICE`
* (Optional) `AZURE_VOICE_LIVE_ENDPOINT` – defaults to `wss://api.voicelive.com/v1`
* (Optional) `VOICE_LIVE_INSTRUCTIONS`
* (Optional) `VOICE_LIVE_VERBOSE` to enable debug logging

If required variables are missing the application will exit (CLI) or return an error state (web).

