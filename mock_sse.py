#!/usr/bin/env python3
"""QuinHub M4 联调用 mock SSE 服务器（OpenAI 兼容协议）。
监听 127.0.0.1:8899：GET /v1/models 返回模型列表；POST /v1/chat/completions 流式回 canned Markdown。
用法：python3 mock_sse.py（WSL 内），配合 adb reverse tcp:8899 tcp:8899 供模拟器访问。
"""
import asyncio
import json

REPLY = """好的，这是来自 mock 的流式回复。

**加粗** 与 `inline code`，然后是一个代码块：

```python
def hello(name):
    return f"hello {name}"
```

列表：
- 第一项
- 第二项

完毕 ✅
"""

MODELS = {"object": "list", "data": [{"id": "mock-1", "object": "model"}]}


def sse_chunks():
    yield 'data: {"choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}\n\n'
    for ch in REPLY:
        yield f'data: {json.dumps({"choices": [{"index": 0, "delta": {"content": ch}, "finish_reason": None}]}, ensure_ascii=False)}\n\n'
    yield 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\n'
    yield 'data: {"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":%d}}\n\n' % len(REPLY)
    yield 'data: [DONE]\n\n'


async def handle(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    try:
        headers = await reader.readuntil(b"\r\n\r\n")
        content_length = 0
        for line in headers.decode("latin1").split("\r\n"):
            if line.lower().startswith("content-length:"):
                content_length = int(line.split(":", 1)[1].strip())
        if content_length:
            await reader.readexactly(content_length)

        path = headers.decode("latin1").split(" ")[1]
        if path.endswith("/models"):
            body = json.dumps(MODELS)
            writer.write(
                f"HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {len(body)}\r\nconnection: close\r\n\r\n{body}".encode()
            )
        else:
            writer.write(
                b"HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\nconnection: close\r\n\r\n"
            )
            for chunk in sse_chunks():
                writer.write(chunk.encode("utf-8"))
                await writer.drain()
                await asyncio.sleep(0.03)
        await writer.drain()
    except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError):
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass


async def main():
    server = await asyncio.start_server(handle, "127.0.0.1", 8899)
    print("mock SSE on 127.0.0.1:8899")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
