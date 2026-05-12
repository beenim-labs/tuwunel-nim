import std/[net, os, sequtils, strutils, unittest]

import service/storage/provider

type
  MockS3ServerArgs = object
    port: Port

proc reserveLocalPort(): Port =
  var socket = newSocket()
  socket.setSockOpt(OptReuseAddr, true)
  socket.bindAddr(Port(0), "127.0.0.1")
  result = socket.getLocalAddr()[1]
  socket.close()

proc recvExact(socket: Socket; size: int): string =
  result = ""
  while result.len < size:
    let chunk = socket.recv(size - result.len)
    if chunk.len == 0:
      break
    result.add(chunk)

proc recvRequest(socket: Socket): tuple[startLine: string, headers: seq[string], body: string] =
  result = (startLine: socket.recvLine().strip(chars = {'\c', '\L'}), headers: @[], body: "")
  var contentLength = 0
  while true:
    let line = socket.recvLine().strip(chars = {'\c', '\L'})
    if line.len == 0:
      break
    result.headers.add(line)
    if line.toLowerAscii().startsWith("content-length:"):
      contentLength = parseInt(line.split(":", 1)[1].strip())
  if contentLength > 0:
    result.body = socket.recvExact(contentLength)

proc hasSignedS3Headers(headers: openArray[string]): bool =
  var hasAuth = false
  var hasDate = false
  var hasPayloadHash = false
  for raw in headers:
    let line = raw.toLowerAscii()
    if line.startsWith("authorization: aws4-hmac-sha256"):
      hasAuth = true
    elif line.startsWith("x-amz-date:"):
      hasDate = true
    elif line.startsWith("x-amz-content-sha256:"):
      hasPayloadHash = true
  hasAuth and hasDate and hasPayloadHash

proc sendHttp(socket: Socket; status, body: string; extraHeaders = ""; contentLength = -1) =
  let length = if contentLength >= 0: contentLength else: body.len
  socket.send(
    "HTTP/1.1 " & status & "\r\n" &
    "Content-Length: " & $length & "\r\n" &
    "Connection: close\r\n" &
    extraHeaders &
    "\r\n" &
    body
  )

proc mockSignedS3Server(args: MockS3ServerArgs) {.thread.} =
  var server = newSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(args.port, "127.0.0.1")
  server.listen()
  var stored = ""
  for step in 0 ..< 5:
    var client = newSocket()
    server.accept(client)
    let request = recvRequest(client)
    let parts = request.startLine.split(" ")
    let target = if parts.len >= 2: parts[1] else: ""
    let signed = hasSignedS3Headers(request.headers)
    case step
    of 0:
      if request.startLine.startsWith("PUT ") and
          target == "/test-bucket/base/rooms/one.bin" and
          request.body == "hello" and signed:
        stored = request.body
        client.sendHttp("200 OK", "<PutObjectResult/>")
      else:
        client.sendHttp("400 Bad Request", "bad put")
    of 1:
      if request.startLine.startsWith("GET ") and
          target == "/test-bucket/base/rooms/one.bin" and signed:
        client.sendHttp("200 OK", stored)
      else:
        client.sendHttp("400 Bad Request", "bad get")
    of 2:
      if request.startLine.startsWith("HEAD ") and
          target == "/test-bucket/base/rooms/one.bin" and signed:
        client.sendHttp("200 OK", "", contentLength = stored.len)
      else:
        client.sendHttp("400 Bad Request", "bad head")
    of 3:
      if request.startLine.startsWith("GET ") and
          target == "/test-bucket?list-type=2&prefix=base" and signed:
        client.sendHttp(
          "200 OK",
          "<ListBucketResult><Contents><Key>base/rooms/one.bin</Key><Size>" &
            $stored.len & "</Size></Contents></ListBucketResult>"
        )
      else:
        client.sendHttp("400 Bad Request", "bad list")
    else:
      if request.startLine.startsWith("DELETE ") and
          target == "/test-bucket/base/rooms/one.bin" and signed:
        client.sendHttp("204 No Content", "")
      else:
        client.sendHttp("400 Bad Request", "bad delete")
    client.close()
  server.close()

suite "Storage provider parity":
  test "chunked follows Rust object-store chunk behavior":
    check chunked("abcdefghijklmnopqrstuvwxy", 10) == @["abcdefghij", "klmnopqrst", "uvwxy"]
    check chunked("abcdefghijklmnopqrstuvwxyz1234", 10) == @["abcdefghij", "klmnopqrst", "uvwxyz1234"]
    check chunked("abcde", 10) == @["abcde"]
    check chunked("", 10).len == 0
    check chunked("payload", high(int)) == @["payload"]

  test "local provider stores, lists, copies, renames and deletes objects":
    let root = getTempDir() / "tuwunel_nim_storage_provider"
    if dirExists(root):
      removeDir(root)
    let provider = initLocalProvider("media", root, deleteEmptyDirectories = true)

    let put = provider.putOne("rooms/one.bin", "hello")
    check put.location == "rooms/one.bin"
    check put.size == 5
    check provider.get("rooms/one.bin") == "hello"
    check provider.head("rooms/one.bin").size == 5

    provider.copy("rooms/one.bin", "rooms/two.bin", cmCreate)
    check provider.get("rooms/two.bin") == "hello"

    provider.rename("rooms/two.bin", "archive/two.bin")
    check provider.get("archive/two.bin") == "hello"
    check provider.list().mapIt(it.location) == @["archive/two.bin", "rooms/one.bin"]

    check provider.deleteOne("rooms/one.bin")
    check not provider.deleteOne("rooms/missing.bin")
    provider.ping()

  test "local provider rejects path traversal":
    let root = getTempDir() / "tuwunel_nim_storage_provider_escape"
    if dirExists(root):
      removeDir(root)
    let provider = initLocalProvider("media", root)
    expect ValueError:
      discard provider.putOne("../escape.bin", "nope")

  test "s3 provider performs signed native object operations":
    let port = reserveLocalPort()
    var thread: Thread[MockS3ServerArgs]
    {.push warning[ProveInit]: off.}
    createThread(thread, mockSignedS3Server, MockS3ServerArgs(port: port))
    {.pop.}
    sleep(100)

    let provider = initS3Provider(
      "archive",
      bucket = "test-bucket",
      endpoint = "http://127.0.0.1:" & $int(port),
      basePath = "base",
      key = "test-key",
      secret = "test-secret",
      useHttps = false
    )
    let put = provider.putOne("rooms/one.bin", "hello")
    check put.location == "rooms/one.bin"
    check put.size == 5
    check provider.get("rooms/one.bin") == "hello"
    check provider.head("rooms/one.bin").size == 5
    check provider.list().mapIt(it.location) == @["rooms/one.bin"]
    check provider.deleteOne("rooms/one.bin")
    joinThread(thread)
