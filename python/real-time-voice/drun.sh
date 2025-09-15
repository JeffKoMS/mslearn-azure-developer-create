docker run --rm -p 5000:5000 \
    -e AZURE_VOICE_LIVE_ENDPOINT="https://jeffko-voice-live-resource.cognitiveservices.azure.com/" \
    -e VOICE_LIVE_MODEL="gpt-4o-realtime-preview" \
    -e VOICE_LIVE_VOICE="alloy" \
    -e VOICE_LIVE_INSTRUCTIONS="You are a helpful AI assistant. Respond naturally and conversationally. Keep your responses concise but engaging." \
    real-time-voice:latest