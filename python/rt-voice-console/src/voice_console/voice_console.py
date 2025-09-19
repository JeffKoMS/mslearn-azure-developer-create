import os
import sys
import asyncio
import base64
import signal
import threading
import queue
from azure.ai.voicelive.models import ServerEventType
from typing import Union, Optional, TYPE_CHECKING, cast
import logging


# Audio processing is factored out into audio_processing.py
from .audio_processing import AudioProcessor, check_audio_system

# Environment variable loading
try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    print("Note: python-dotenv not installed. Using existing environment variables.")

# Azure VoiceLive SDK imports
from azure.core.credentials import AzureKeyCredential, TokenCredential
from azure.identity import DefaultAzureCredential

from azure.ai.voicelive.aio import connect

if TYPE_CHECKING:
    # Only needed for type checking; avoids runtime import issues
    from azure.ai.voicelive.aio import VoiceLiveConnection

from azure.ai.voicelive.models import (
    RequestSession,
    ServerVad,
    AzureStandardVoice,
    Modality,
    AudioFormat,
)

# Set up logging
# Default to ERROR level to reduce console noise for end users. All user-facing informational
# messages already use print() so we only surface warnings/errors from the logger unless
# the VOICE_LIVE_VERBOSE environment variable is set (handled later) to elevate to DEBUG.
logging.basicConfig(level=logging.ERROR, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", force=True)
logger = logging.getLogger(__name__)


class BasicVoiceAssistant:
    """Basic voice assistant implementing the VoiceLive SDK patterns."""

    def __init__(
        self,
        endpoint: str,
        credential: Union[AzureKeyCredential, TokenCredential],
        model: str,
        voice: str,
        instructions: str,
    ):

        self.endpoint = endpoint
        self.credential = credential
        self.model = model
        self.voice = voice
        self.instructions = instructions
        self.connection: Optional["VoiceLiveConnection"] = None
        self.audio_processor: Optional[AudioProcessor] = None
        self.session_ready = False
        self.conversation_started = False

    async def start(self):
        """Start the voice assistant session."""
        try:
            logger.info(f"Connecting to VoiceLive API with model {self.model}")

            # Connect to VoiceLive WebSocket API
            async with connect(
                endpoint=self.endpoint,
                credential=self.credential,
                model=self.model,
                connection_options={
                    "max_msg_size": 10 * 1024 * 1024,
                    "heartbeat": 20,
                    "timeout": 20,
                },
            ) as connection:
                conn = connection
                self.connection = conn

                # Initialize audio processor
                ap = AudioProcessor(conn)
                self.audio_processor = ap

                # Configure session for voice conversation
                await self._setup_session()

                # Start audio systems
                await ap.start_playback()

                logger.info("Voice assistant ready! Start speaking...")
                print("\n" + "=" * 60)
                print("🎤 VOICE ASSISTANT READY")
                print("Start speaking to begin conversation")
                print("Press Ctrl+C to exit")
                print("=" * 60 + "\n")

                # Process events
                await self._process_events()

        except KeyboardInterrupt:
            logger.info("Received interrupt signal, shutting down...")

        except Exception as e:
            logger.error(f"Connection error: {e}")
            raise

        # Cleanup
        if self.audio_processor:
            await self.audio_processor.cleanup()

    async def _setup_session(self):
        """Configure the VoiceLive session for audio conversation."""
        logger.info("Setting up voice conversation session...")

        # Create strongly typed voice configuration
        voice_config: Union[AzureStandardVoice, str]
        if self.voice.startswith("en-US-") or self.voice.startswith("en-CA-") or "-" in self.voice:
            # Azure voice
            voice_config = AzureStandardVoice(name=self.voice, type="azure-standard")
        else:
            # OpenAI voice (alloy, echo, fable, onyx, nova, shimmer)
            voice_config = self.voice

        # Create strongly typed turn detection configuration
        turn_detection_config = ServerVad(threshold=0.5, prefix_padding_ms=300, silence_duration_ms=500)

        # Create strongly typed session configuration
        session_config = RequestSession(
            modalities=[Modality.TEXT, Modality.AUDIO],
            instructions=self.instructions,
            voice=voice_config,
            input_audio_format=AudioFormat.PCM16,
            output_audio_format=AudioFormat.PCM16,
            turn_detection=turn_detection_config,
        )

        conn = self.connection
        assert conn is not None, "Connection must be established before setting up session"
        await conn.session.update(session=session_config)

        logger.info("Session configuration sent")

    async def _process_events(self):
        """Process events from the VoiceLive connection."""
        try:
            conn = self.connection
            assert conn is not None, "Connection must be established before processing events"
            async for event in conn:
                await self._handle_event(event)

        except KeyboardInterrupt:
            logger.info("Event processing interrupted")
        except Exception as e:
            logger.error(f"Error processing events: {e}")
            raise

    async def _handle_event(self, event):
        """Handle different types of events from VoiceLive."""
        logger.debug(f"Received event: {event.type}")
        ap = self.audio_processor
        conn = self.connection
        assert ap is not None, "AudioProcessor must be initialized"
        assert conn is not None, "Connection must be established"

        if event.type == ServerEventType.SESSION_UPDATED:
            logger.info(f"Session ready: {event.session.id}")
            self.session_ready = True

            # Start audio capture once session is ready
            await ap.start_capture()

        elif event.type == ServerEventType.INPUT_AUDIO_BUFFER_SPEECH_STARTED:
            logger.info("🎤 User started speaking - stopping playback")
            print("🎤 Listening...")

            # Stop current assistant audio playback (interruption handling)
            await ap.stop_playback()

            # Cancel any ongoing response
            try:
                await conn.response.cancel()
            except Exception as e:
                logger.debug(f"No response to cancel: {e}")

        elif event.type == ServerEventType.INPUT_AUDIO_BUFFER_SPEECH_STOPPED:
            logger.info("🎤 User stopped speaking")
            print("🤔 Processing...")

            # Restart playback system for response
            await ap.start_playback()

        elif event.type == ServerEventType.RESPONSE_CREATED:
            logger.info("🤖 Assistant response created")

        elif event.type == ServerEventType.RESPONSE_AUDIO_DELTA:
            # Stream audio response to speakers
            logger.debug("Received audio delta")
            await ap.queue_audio(event.delta)

        elif event.type == ServerEventType.RESPONSE_AUDIO_DONE:
            logger.info("🤖 Assistant finished speaking")
            print("🎤 Ready for next input...")

        elif event.type == ServerEventType.RESPONSE_DONE:
            logger.info("✅ Response complete")

        elif event.type == ServerEventType.ERROR:
            logger.error(f"❌ VoiceLive error: {event.error.message}")
            print(f"Error: {event.error.message}")

        elif event.type == ServerEventType.CONVERSATION_ITEM_CREATED:
            logger.debug(f"Conversation item created: {event.item.id}")

        else:
            logger.debug(f"Unhandled event type: {event.type}")


## Removed command-line argument parsing; configuration now sourced from environment variables (.env supported)


async def main_async():
    """Main coroutine function.

    Renamed from `main` to `main_async` so we can expose a synchronous
    `main()` wrapper. Some packaging entry points call `main` directly as a
    normal function; if `main` is an async function that returns a coroutine
    object, that can produce the "coroutine ... was never awaited" runtime
    warning. The synchronous `main()` below calls `asyncio.run(main_async())`.
    """
    # Load configuration from environment
    endpoint = os.environ.get("AZURE_VOICE_LIVE_ENDPOINT")
    model = os.environ.get("VOICE_LIVE_MODEL")
    voice = os.environ.get("VOICE_LIVE_VOICE")
    instructions = os.environ.get("VOICE_LIVE_INSTRUCTIONS")
    verbose = os.environ.get("VOICE_LIVE_VERBOSE")

    if verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        logger.debug("Verbose logging enabled via VOICELIVE_VERBOSE env var")

    # Authentication now fixed to DefaultAzureCredential (API key removed)
    credential: Union[AzureKeyCredential, TokenCredential] = DefaultAzureCredential()  # type: ignore[assignment]
    auth_mode = "default-azure-credential"

    # Basic required env validation
    missing = []
    if not model:
        missing.append("VOICE_LIVE_MODEL")
    if not voice:
        missing.append("VOICE_LIVE_VOICE")
    if missing:
        logger.error("Missing required environment variables: %s", ", ".join(missing))
        raise SystemExit(1)
    if not instructions:
        instructions = "You are a helpful voice assistant."
    # At this point model and voice are not None due to validation above; narrow types for type checker
    model = cast(str, model)
    voice = cast(str, voice)

    logger.info(
        "Starting Voice Assistant with config | endpoint=%s model=%s voice=%s auth=%s",
        endpoint,
        model,
        voice,
        auth_mode,
    )

    try:
        # Create client with appropriate credential
        # Create and start voice assistant
        assistant = BasicVoiceAssistant(
            endpoint=endpoint,
            credential=credential,
            model=model,
            voice=voice,
            instructions=instructions,
        )

        # Setup signal handlers for graceful shutdown
        def signal_handler(sig, frame):
            logger.info("Received shutdown signal")
            raise KeyboardInterrupt()

        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        # Start the assistant
        await assistant.start()

    except KeyboardInterrupt:
        print("\n👋 Voice assistant shut down. Goodbye!")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        print(f"❌ Error: {e}")
        sys.exit(1)


def main():
    """Synchronous wrapper for the main coroutine.

    Call this from packaging entry points (console_scripts) or from
    environments that expect a regular callable. This avoids returning a
    coroutine object to callers that won't await it.
    """
    asyncio.run(main_async())


def run():
    """Synchronous entry point used by console scripts / containers.

    Kept for backwards compatibility with earlier versions of this module.
    It simply delegates to the synchronous ``main()`` wrapper above.
    """
    main()


if __name__ == "__main__":
    # Check for required dependencies
    dependencies = {
        "pyaudio": "Audio processing",
        "azure.ai.voicelive": "Azure VoiceLive SDK",
        "azure.core": "Azure Core libraries",
    }

    missing_deps = []
    for dep, description in dependencies.items():
        try:
            __import__(dep.replace("-", "_"))
        except ImportError:
            missing_deps.append(f"{dep} ({description})")

    if missing_deps:
        print("❌ Missing required dependencies:")
        for dep in missing_deps:
            print(f"  - {dep}")
        print("\nInstall with: pip install azure-ai-voicelive pyaudio python-dotenv")
        sys.exit(1)

    # Check audio system (delegated to audio_processing.check_audio_system)
    try:
        check_audio_system()
    except Exception as e:
        print(f"❌ Audio system check failed: {e}")
        sys.exit(1)

    print("🎙️  Basic Voice Assistant with Azure VoiceLive SDK")
    print("=" * 50)

    # Run the assistant
    run()
