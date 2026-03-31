///|
test "open and close" {
  let path = b"/tmp/co-io-test-open\x00"
  let fd = @io.open(path, 64 | 1 | 512, 0o644) // O_CREAT | O_WRONLY | O_TRUNC
  @io.close(fd)
}

///|
test "write and read" {
  let path = b"/tmp/co-io-test-rw\x00"
  let fd = @io.open(path, 64 | 1 | 512, 0o644)
  let data = b"hello, io_uring!"
  let written = @io.write(fd, data, data.length())
  assert_eq(written, data.length())
  @io.close(fd)
  let fd = @io.open(path, 0, 0) // O_RDONLY
  let buf = Bytes::make(64, 0)
  let n = @io.read(fd, buf, 64)
  @io.close(fd)
  assert_eq(n, data.length())
  for i in 0..<n {
    assert_eq(buf[i], data[i])
  }
}

///|
test "concurrent IO" {
  let path = b"/tmp/co-io-test-concurrent\x00"
  let fd = @io.open(path, 64 | 1 | 512, 0o644)
  let data = b"concurrent test"
  let _ = @io.write(fd, data, data.length())
  @io.close(fd)
  let f1 : @co.Future[Int] = @co.Future::new()
  let f2 : @co.Future[Int] = @co.Future::new()
  let _ = @co.Task::new(name="reader1", fn() {
    let fd = @io.open(path, 0, 0) catch { _ => abort("open failed") }
    let buf = Bytes::make(64, 0)
    let n = @io.read(fd, buf, 64) catch { _ => abort("read failed") }
    @io.close(fd) catch {
      _ => abort("close failed")
    }
    f1.set(n)
  })
  let _ = @co.Task::new(name="reader2", fn() {
    let fd = @io.open(path, 0, 0) catch { _ => abort("open failed") }
    let buf = Bytes::make(64, 0)
    let n = @io.read(fd, buf, 64) catch { _ => abort("read failed") }
    @io.close(fd) catch {
      _ => abort("close failed")
    }
    f2.set(n)
  })
  assert_eq(f1.wait(), data.length())
  assert_eq(f2.wait(), data.length())
}

///|
test "open non-existent file" {
  let path = b"/tmp/co-io-test-nonexistent-file-that-should-not-exist\x00"
  let result = try {
    let _ = @io.open(path, 0, 0)
    Ok(())
  } catch {
    _ => Err(())
  }
  assert_eq(result, Err(()))
}
