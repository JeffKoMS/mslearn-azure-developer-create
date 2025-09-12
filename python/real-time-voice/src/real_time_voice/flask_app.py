from __future__ import annotations

from pathlib import Path
from flask import Flask, render_template

app = Flask(__name__, template_folder=str(Path(__file__).parent / "templates"))


@app.route("/")
def index():
    return render_template("index.html")


def main() -> None:
    # Basic dev server; in production consider a WSGI/ASGI server like gunicorn or uvicorn.
    app.run(host="127.0.0.1", port=5000, debug=True)


if __name__ == "__main__":  # pragma: no cover
    main()
