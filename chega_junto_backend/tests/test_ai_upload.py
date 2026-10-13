import asyncio

from app.api.audio_upload_limit import AudioUploadLimit
from app.services.report_ai import AUDIO_MAX_BYTES


def test_chunked_audio_rejected_before_parser_or_provider():
    calls, sent = [], []

    async def app(scope, receive, send):
        calls.append(True)

    messages = iter(
        [
            {"type": "http.request", "body": b"x" * AUDIO_MAX_BYTES, "more_body": True},
            {"type": "http.request", "body": b"x" * 65537, "more_body": False},
        ]
    )

    async def receive():
        return next(messages)

    async def send(message):
        sent.append(message)

    asyncio.run(
        AudioUploadLimit(app)(
            {"type": "http", "path": "/api/v1/appointments/1/report/transcription"},
            receive,
            send,
        )
    )
    assert calls == []
    assert sent[0]["status"] == 413
    assert b"audio_too_large" in sent[1]["body"]


def test_chunked_valid_body_replayed_exactly():
    chunks = [b"a", b"b", b"c"]
    messages = iter(
        [
            {"type": "http.request", "body": chunk, "more_body": i < len(chunks) - 1}
            for i, chunk in enumerate(chunks)
        ]
    )
    collected = []

    async def app(scope, receive, send):
        while True:
            message = await receive()
            collected.append(message["body"])
            if not message["more_body"]:
                break

    async def receive():
        return next(messages)

    async def send(message):
        pass

    asyncio.run(
        AudioUploadLimit(app)(
            {"type": "http", "path": "/api/v1/appointments/1/report/transcription"},
            receive,
            send,
        )
    )
    assert collected == chunks
