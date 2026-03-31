///|
struct Handle(UInt64)

///|
priv type Io

///|
extern "c" fn Io::new() -> Io = "moonbit_co_io_create"

///|
priv struct Request {
  task : @co.Task
  mut value : UInt64
  mut error : Int
}

///|
suberror Errno {
  Errno(Int)
}

///|
#borrow(io, path, req)
extern "c" fn submit_open(
  io : Io,
  path : Bytes,
  flags : Int,
  mode : Int,
  req : Request,
) = "moonbit_co_io_submit_open"

///|
#borrow(io, bytes, req)
extern "c" fn submit_read(
  io : Io,
  handle : UInt64,
  bytes : Bytes,
  length : Int,
  req : Request,
) = "moonbit_co_io_submit_read"

///|
#borrow(io, bytes, req)
extern "c" fn submit_write(
  io : Io,
  handle : UInt64,
  bytes : Bytes,
  length : Int,
  req : Request,
) = "moonbit_co_io_submit_write"

///|
#borrow(io, req)
extern "c" fn submit_close(io : Io, handle : UInt64, req : Request) = "moonbit_co_io_submit_close"

///|
#borrow(io, reqs, values, errors, length)
extern "c" fn io_suspend(
  io : Io,
  reqs : FixedArray[Request],
  values : FixedArray[UInt64],
  errors : FixedArray[Int],
  length : Ref[Int],
  timeout : Int64,
) = "moonbit_co_io_poll"

///|
let max_completions : Int = 256

///|
let ring : Io = Io::new()

///|
let poll_reqs : FixedArray[Request] = FixedArray::make(max_completions, Request::{
  task: @co.Task::current(),
  value: 0,
  error: 0,
})

///|
let poll_values : FixedArray[UInt64] = FixedArray::make(max_completions, 0)

///|
let poll_errors : FixedArray[Int] = FixedArray::make(max_completions, 0)

///|
pub fn suspend() -> Unit {
  let length = Ref::new(max_completions)
  io_suspend(ring, poll_reqs, poll_values, poll_errors, length, -1)
  for i in 0..<length.val {
    poll_reqs[i].value = poll_values[i]
    poll_reqs[i].error = poll_errors[i]
    poll_reqs[i].task.schedule()
  }
}

///|
pub fn open(path : Bytes, flags : Int, mode : Int) -> Handle raise Errno {
  let req = Request::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_open(ring, path, flags, mode, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise Errno(req.error)
  }
  req.value
}

///|
pub fn read(handle : Handle, bytes : Bytes, length : Int) -> Int raise Errno {
  let req = Request::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_read(ring, handle.0, bytes, length, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise Errno(req.error)
  }
  req.value.to_int()
}

///|
pub fn write(handle : Handle, bytes : Bytes, length : Int) -> Int raise Errno {
  let req = Request::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_write(ring, handle.0, bytes, length, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise Errno(req.error)
  }
  req.value.to_int()
}

///|
pub fn close(handle : Handle) -> Unit raise Errno {
  let req = Request::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_close(ring, handle.0, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise Errno(req.error)
  }
}
