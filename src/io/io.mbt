///|
priv type Io

///|
extern "c" fn Io::new() -> Io = "moonbit_co_io_create"

///|
priv struct IORequest {
  task : @co.Task
  mut value : UInt64
  mut error : Int
}

///|
suberror IOError {
  IOError(Int)
}

///|
#borrow(io, path, req)
extern "c" fn submit_open(
  io : Io,
  path : Bytes,
  flags : Int,
  mode : Int,
  req : IORequest,
) = "moonbit_co_io_submit_open"

///|
#borrow(io, bytes, req)
extern "c" fn submit_read(
  io : Io,
  handle : UInt64,
  bytes : Bytes,
  length : Int,
  req : IORequest,
) = "moonbit_co_io_submit_read"

///|
#borrow(io, bytes, req)
extern "c" fn submit_write(
  io : Io,
  handle : UInt64,
  bytes : Bytes,
  length : Int,
  req : IORequest,
) = "moonbit_co_io_submit_write"

///|
#borrow(io, req)
extern "c" fn submit_close(io : Io, handle : UInt64, req : IORequest) = "moonbit_co_io_submit_close"

///|
#borrow(io, reqs, values, errors, length)
extern "c" fn io_poll(
  io : Io,
  reqs : FixedArray[IORequest],
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
let poll_reqs : FixedArray[IORequest] = FixedArray::make(max_completions, IORequest::{
  task: @co.Task::current(),
  value: 0,
  error: 0,
})

///|
let poll_values : FixedArray[UInt64] = FixedArray::make(max_completions, 0)

///|
let poll_errors : FixedArray[Int] = FixedArray::make(max_completions, 0)

///|
pub fn yield_() -> Unit {
  let length = Ref::new(max_completions)
  io_poll(ring, poll_reqs, poll_values, poll_errors, length, -1)
  for i in 0..<length.val {
    poll_reqs[i].value = poll_values[i]
    poll_reqs[i].error = poll_errors[i]
    poll_reqs[i].task.schedule()
  }
}

///|
pub fn open(path : Bytes, flags : Int, mode : Int) -> UInt64 raise IOError {
  let req = IORequest::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_open(ring, path, flags, mode, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise IOError(req.error)
  }
  req.value
}

///|
pub fn read(handle : UInt64, bytes : Bytes, length : Int) -> Int raise IOError {
  let req = IORequest::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_read(ring, handle, bytes, length, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise IOError(req.error)
  }
  req.value.to_int()
}

///|
pub fn write(handle : UInt64, bytes : Bytes, length : Int) -> Int raise IOError {
  let req = IORequest::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_write(ring, handle, bytes, length, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise IOError(req.error)
  }
  req.value.to_int()
}

///|
pub fn close(handle : UInt64) -> Unit raise IOError {
  let req = IORequest::{ task: @co.Task::current(), value: 0, error: 0 }
  submit_close(ring, handle, req)
  @co.Task::suspend()
  if req.error != 0 {
    raise IOError(req.error)
  }
}
