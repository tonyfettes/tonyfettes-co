# macOS GCD I/O Backend Design

## Summary

Add a macOS backend to the `io/` module using Grand Central Dispatch (GCD).
GCD is used as a thread pool to dispatch POSIX I/O syscalls asynchronously,
with a completion ring buffer and semaphore bridging GCD's callback model
into the existing submit/poll proactor interface.

## Cross-platform interface changes

### New submit signature

Each submit function now takes `value`, `error`, and `task` as separate
pointers. The C backend writes results directly through `value`/`error`
pointers, and `poll` only returns completed task pointers.

```moonbit
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

#owned(io, value, error, task)
extern "c" fn submit_close(
  io : Io,
  handle : UInt64,
  value : Ref[UInt64],
  error : Ref[Int],
  task : @co.Task,
) = "moonbit_co_io_submit_close"
```

### New poll signature

Poll only returns task pointers. Results are already written through
value/error pointers by the backend.

```moonbit
#borrow(io, tasks, length)
extern "c" fn io_poll(
  io : Io,
  tasks : FixedArray[@co.Task],
  length : Ref[Int],
  timeout : Int64,
) = "moonbit_co_io_poll"
```

### Updated suspend

```moonbit
pub fn suspend() -> Unit {
  let length = Ref::new(max_completions)
  io_poll(ring, poll_tasks, length, -1)
  for i in 0..<length.val {
    poll_tasks[i].schedule()
  }
}
```

### Ownership contract

All GC-managed objects captured beyond the extern call's lifetime are
`#owned`. The C backend calls `moonbit_decref` when done.

| Param | Owned? | When to decref |
|---|---|---|
| `io` | `#owned` | io_uring: end of submit. GCD: end of block. |
| `path`/`bytes` | `#owned` | io_uring: end of submit. GCD: end of block. |
| `value` | `#owned` | After writing result (poll or block). |
| `error` | `#owned` | After writing result (poll or block). |
| `task` | `#owned` | After push_completion (poll or block). |

## C interface (io.h)

```c
struct moonbit_co_io;

MOONBIT_FFI_EXPORT
struct moonbit_co_io *moonbit_co_io_create(void);

MOONBIT_FFI_EXPORT
void moonbit_co_io_submit_open(
  struct moonbit_co_io *io,
  const char *path,
  int32_t flags,
  int32_t mode,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void moonbit_co_io_submit_read(
  struct moonbit_co_io *io,
  uint64_t handle,
  void *bytes,
  int32_t length,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void moonbit_co_io_submit_write(
  struct moonbit_co_io *io,
  uint64_t handle,
  void *bytes,
  int32_t length,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void moonbit_co_io_submit_close(
  struct moonbit_co_io *io,
  uint64_t handle,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void moonbit_co_io_poll(
  struct moonbit_co_io *io,
  void **tasks,
  int32_t *count,
  int64_t timeout
);
```

## GCD backend (io_gcd.c)

### State

```c
#include <dispatch/dispatch.h>

struct moonbit_co_io {
  dispatch_queue_t queue;
  dispatch_semaphore_t sem;

  // Completion ring buffer
  // Producer: GCD worker threads (one per block)
  // Consumer: scheduler thread (poll)
  struct { void *task; } completions[256];
  _Atomic uint32_t cq_head;
  _Atomic uint32_t cq_tail;
};
```

### Create/finalize

```c
static void moonbit_co_io_finalize(void *ptr) {
  struct moonbit_co_io *io = (struct moonbit_co_io *)ptr;
  if (io->queue) dispatch_release(io->queue);
  if (io->sem)   dispatch_release(io->sem);
}

struct moonbit_co_io *moonbit_co_io_create(void) {
  struct moonbit_co_io *io = (struct moonbit_co_io *)
    moonbit_make_external_object(moonbit_co_io_finalize,
                                 sizeof(struct moonbit_co_io));
  memset(io, 0, sizeof(*io));
  io->queue = dispatch_queue_create(
    "co.io", DISPATCH_QUEUE_CONCURRENT);
  io->sem = dispatch_semaphore_create(0);
  return io;
}
```

### Completion push

```c
static void push_completion(struct moonbit_co_io *io, void *task) {
  uint32_t tail = atomic_load_explicit(&io->cq_tail, memory_order_relaxed);
  io->completions[tail & 255].task = task;
  atomic_store_explicit(&io->cq_tail, tail + 1, memory_order_release);
  dispatch_semaphore_signal(io->sem);
}
```

### Operations

```c
void moonbit_co_io_submit_open(io, path, flags, mode, value, error, task) {
  dispatch_async(io->queue, ^{
    int fd = open(path, flags, mode);
    if (fd < 0) { *value = 0; *error = errno; }
    else        { *value = (uint64_t)fd; *error = 0; }
    moonbit_decref(io);
    moonbit_decref((void *)path);
    moonbit_decref(value);
    moonbit_decref(error);
    push_completion(io, task);
    moonbit_decref(task);
  });
}

void moonbit_co_io_submit_read(io, handle, bytes, length, value, error, task) {
  dispatch_async(io->queue, ^{
    ssize_t n = read((int)handle, bytes, length);
    if (n < 0) { *value = 0; *error = errno; }
    else       { *value = (uint64_t)n; *error = 0; }
    moonbit_decref(io);
    moonbit_decref(bytes);
    moonbit_decref(value);
    moonbit_decref(error);
    push_completion(io, task);
    moonbit_decref(task);
  });
}

void moonbit_co_io_submit_write(io, handle, bytes, length, value, error, task) {
  dispatch_async(io->queue, ^{
    ssize_t n = write((int)handle, bytes, length);
    if (n < 0) { *value = 0; *error = errno; }
    else       { *value = (uint64_t)n; *error = 0; }
    moonbit_decref(io);
    moonbit_decref(bytes);
    moonbit_decref(value);
    moonbit_decref(error);
    push_completion(io, task);
    moonbit_decref(task);
  });
}

void moonbit_co_io_submit_close(io, handle, value, error, task) {
  dispatch_async(io->queue, ^{
    int r = close((int)handle);
    if (r < 0) { *value = 0; *error = errno; }
    else       { *value = 0; *error = 0; }
    moonbit_decref(io);
    moonbit_decref(value);
    moonbit_decref(error);
    push_completion(io, task);
    moonbit_decref(task);
  });
}
```

### Poll

```c
void moonbit_co_io_poll(io, tasks, count, timeout) {
  // Block until at least one completion
  dispatch_semaphore_wait(io->sem, DISPATCH_TIME_FOREVER);

  uint32_t head = atomic_load_explicit(&io->cq_head, memory_order_relaxed);
  uint32_t tail = atomic_load_explicit(&io->cq_tail, memory_order_acquire);
  int32_t max = *count;
  int32_t n = 0;

  while (head != tail && n < max) {
    tasks[n] = io->completions[head & 255].task;
    head++;
    n++;
    if (head != tail)
      dispatch_semaphore_wait(io->sem, DISPATCH_TIME_NOW);
  }

  atomic_store_explicit(&io->cq_head, head, memory_order_release);
  *count = n;
}
```

## io_uring backend changes

The io_uring backend needs updates to match the new interface.

### Side table for request state

io_uring's `user_data` is 64 bits — cannot hold three pointers. Add a
side table indexed by SQE slot:

```c
struct moonbit_co_io {
  // ... existing ring state ...

  // Per-slot request state (indexed by sqe slot)
  struct {
    uint64_t *value;
    int32_t *error;
    void *task;
  } reqs[256];
};
```

### Submit changes

Each submit function stores value/error/task in the side table, stores
the slot index as user_data, and decrefs io + path/bytes immediately:

```c
void moonbit_co_io_submit_read(io, handle, bytes, length, value, error, task) {
  struct io_uring_sqe *sqe = get_sqe(io);
  uint32_t slot = (io->sq_tail - 1) & *io->sq_ring_mask;
  sqe->opcode = IORING_OP_READ;
  sqe->fd = (int32_t)handle;
  sqe->addr = (uint64_t)(uintptr_t)bytes;
  sqe->len = (uint32_t)length;
  sqe->off = (uint64_t)-1;
  sqe->user_data = slot;
  io->reqs[slot].value = value;
  io->reqs[slot].error = error;
  io->reqs[slot].task = task;
  moonbit_decref(io);
  moonbit_decref(bytes);
}
```

### Poll changes

Poll writes results through stored pointers, decrefs them, and returns
task pointers:

```c
void moonbit_co_io_poll(io, tasks, count, timeout) {
  // ... flush + drain cqes ...
  while (head != tail && n < max) {
    struct io_uring_cqe *cqe = &io->cqes[head & mask];
    uint32_t slot = (uint32_t)cqe->user_data;
    if (cqe->res >= 0) {
      *io->reqs[slot].value = (uint64_t)cqe->res;
      *io->reqs[slot].error = 0;
    } else {
      *io->reqs[slot].value = 0;
      *io->reqs[slot].error = -cqe->res;
    }
    moonbit_decref(io->reqs[slot].value);
    moonbit_decref(io->reqs[slot].error);
    tasks[n] = io->reqs[slot].task;
    // task decref happens on MoonBit side after schedule? No --
    // poll returns raw pointer, MoonBit reads from FixedArray.
    // task is decrefd here since C owns it.
    // But we need the pointer in tasks[n] first.
    n++;
    head++;
  }
  // Decref tasks after copying to output array
  for (int i = 0; i < n; i++) {
    // Actually tasks[i] is written into a MoonBit FixedArray --
    // the array holds a reference. Safe to decref C's ownership.
    moonbit_decref(tasks[i]);
  }
  // ...
}
```

## Implementation plan

1. Update `io.h` with the new function signatures
2. Update `io.mbt` — new extern declarations, updated suspend/open/read/write/close
3. Update `io_uring.c` — side table, new submit/poll, decref calls
4. Add `io_gcd.c` — full GCD backend
5. Update `io.c` — include `io_gcd.c` on `__APPLE__`
6. Test on macOS
