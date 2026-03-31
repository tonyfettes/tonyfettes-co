///|
struct Handle(UInt64)

///|
priv type Io

///|
extern "c" fn Io::new() -> Io = "moonbit_co_io_create"

///|
suberror Errno {
  Errno(Int)
}

///|
#owned(io, path, value, error, task)
extern "c" fn submit_open(
  io : Io,
  path : Bytes,
  flags : Int,
  mode : Int,
  value : Ref[UInt64],
  error : Ref[Int],
  task : @co.Task,
) = "moonbit_co_io_submit_open"

///|
#owned(io, bytes, value, error, task)
extern "c" fn submit_read(
  io : Io,
  handle : UInt64,
  bytes : Bytes,
  length : Int,
  value : Ref[UInt64],
  error : Ref[Int],
  task : @co.Task,
) = "moonbit_co_io_submit_read"

///|
#owned(io, bytes, value, error, task)
extern "c" fn submit_write(
  io : Io,
  handle : UInt64,
  bytes : Bytes,
  length : Int,
  value : Ref[UInt64],
  error : Ref[Int],
  task : @co.Task,
) = "moonbit_co_io_submit_write"

///|
#owned(io, value, error, task)
extern "c" fn submit_close(
  io : Io,
  handle : UInt64,
  value : Ref[UInt64],
  error : Ref[Int],
  task : @co.Task,
) = "moonbit_co_io_submit_close"

///|
#borrow(io, tasks, length)
extern "c" fn io_poll(
  io : Io,
  tasks : FixedArray[@co.Task],
  length : Ref[Int],
  timeout : Int64,
) = "moonbit_co_io_poll"

///|
let max_completions : Int = 256

///|
let ring : Io = Io::new()

///|
let poll_tasks : FixedArray[@co.Task] = FixedArray::make(
  max_completions,
  @co.Task::current(),
)

///|
pub fn suspend() -> Unit {
  let length = Ref::new(max_completions)
  io_poll(ring, poll_tasks, length, -1)
  for i in 0..<length.val {
    poll_tasks[i].schedule()
  }
}

///|
pub fn open(path : Bytes, flags : Int, mode : Int) -> Handle raise Errno {
  let value = Ref::new(0UL)
  let error = Ref::new(0)
  submit_open(ring, path, flags, mode, value, error, @co.Task::current())
  @co.Task::suspend()
  if error.val != 0 {
    raise Errno(error.val)
  }
  Handle(value.val)
}

///|
pub fn read(handle : Handle, bytes : Bytes, length : Int) -> Int raise Errno {
  let value = Ref::new(0UL)
  let error = Ref::new(0)
  submit_read(ring, handle.0, bytes, length, value, error, @co.Task::current())
  @co.Task::suspend()
  if error.val != 0 {
    raise Errno(error.val)
  }
  value.val.to_int()
}

///|
pub fn write(handle : Handle, bytes : Bytes, length : Int) -> Int raise Errno {
  let value = Ref::new(0UL)
  let error = Ref::new(0)
  submit_write(ring, handle.0, bytes, length, value, error, @co.Task::current())
  @co.Task::suspend()
  if error.val != 0 {
    raise Errno(error.val)
  }
  value.val.to_int()
}

///|
pub fn close(handle : Handle) -> Unit raise Errno {
  let value = Ref::new(0UL)
  let error = Ref::new(0)
  submit_close(ring, handle.0, value, error, @co.Task::current())
  @co.Task::suspend()
  if error.val != 0 {
    raise Errno(error.val)
  }
}
