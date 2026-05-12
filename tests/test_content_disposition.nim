import std/unittest

import core/utils/content_disposition

suite "Content-Disposition parity":
  test "MSC2702 inline content types are detected without parameters":
    check contentDispositionType("text/plain; charset=utf-8") == "inline"
    check contentDispositionType("IMAGE/PNG") == "inline"
    check contentDispositionType("application/octet-stream") == "attachment"
    check contentDispositionType("") == "attachment"

  test "headers include sanitized filenames and requested filename precedence":
    check contentDispositionHeader("text/plain", "hello.txt") ==
      "inline; filename=\"hello.txt\""
    check contentDispositionHeader("application/octet-stream", "report.pdf") ==
      "attachment; filename=\"report.pdf\""
    check contentDispositionHeader("image/png", "server.png", "client/name.png") ==
      "inline; filename=\"client_name.png\""
    check contentDispositionHeader("text/plain", "line" & chr(10) & "break.txt") ==
      "inline; filename=\"line_break.txt\""
