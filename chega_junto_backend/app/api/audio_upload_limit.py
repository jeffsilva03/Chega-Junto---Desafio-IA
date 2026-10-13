"""Limite inclusive para multipart chunked, antes do parser criar temporários."""

from starlette.responses import JSONResponse

from app.services.report_ai import AUDIO_MAX_BYTES


class AudioUploadLimit:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or not scope["path"].endswith("/report/transcription"):
            return await self.app(scope, receive, send)
        limit = AUDIO_MAX_BYTES + 65536  # Envelope multipart, validado novamente por arquivo.
        chunks, size = [], 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            size += len(message.get("body", b""))
            if size > limit:
                return await JSONResponse(
                    status_code=413,
                    content={
                        "error": {
                            "code": "audio_too_large",
                            "message": "O áudio deve ter no máximo 10 MB.",
                        }
                    },
                )(scope, receive, send)
            chunks.append(message)
            if not message.get("more_body", False):
                break
        iterator = iter(chunks)

        async def replay():
            try:
                return next(iterator)
            except StopIteration:
                return await receive()

        await self.app(scope, replay, send)
