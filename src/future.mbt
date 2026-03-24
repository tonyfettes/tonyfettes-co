///|
struct Future[T] {
  mut value : T?
  waiter : Array[Task]
}

///|
pub fn[T] Future::new() -> Future[T] {
  Future::{ value: None, waiter: Array::new() }
}

///|
pub fn[T] Future::set(self : Future[T], value : T) -> Unit {
  self.value = Some(value)
  for task in self.waiter {
    task.schedule()
  }
  self.waiter.clear()
}

///|
pub fn[T] Future::wait(self : Future[T]) -> T {
  if self.value is Some(value) {
    return value
  }
  self.waiter.push(Task::current())
  Task::suspend()
  guard self.value is Some(value) else {
    abort("@tonyfettes/co: wait woke up but no value available")
  }
  value
}
