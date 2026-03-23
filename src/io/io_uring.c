#include <errno.h>
#include <fcntl.h>
#include <linux/io_uring.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>

// -- syscall wrappers --

static int
io_uring_setup(uint32_t entries, struct io_uring_params *p) {
  return (int)syscall(SYS_io_uring_setup, entries, p);
}

static int
io_uring_enter(
  int fd,
  uint32_t to_submit,
  uint32_t min_complete,
  uint32_t flags,
  void *sig,
  size_t sigsz
) {
  return (int)syscall(
    SYS_io_uring_enter, fd, to_submit, min_complete, flags, sig, sigsz
  );
}

// -- ring state --

struct moonbit_co_io {
  int ring_fd;

  // Submission queue
  uint32_t *sq_head;
  uint32_t *sq_tail;
  uint32_t *sq_ring_mask;
  uint32_t *sq_ring_entries;
  uint32_t *sq_array;
  struct io_uring_sqe *sqes;

  // Completion queue
  uint32_t *cq_head;
  uint32_t *cq_tail;
  uint32_t *cq_ring_mask;
  uint32_t *cq_ring_entries;
  struct io_uring_cqe *cqes;

  // Pending submission count
  uint32_t sq_pending;
};

static struct moonbit_co_io g_io;
static int g_io_initialized = 0;

static void
io_init(void) {
  if (g_io_initialized)
    return;

  struct io_uring_params params;
  memset(&params, 0, sizeof(params));

  int fd = io_uring_setup(256, &params);
  if (fd < 0)
    abort();

  g_io.ring_fd = fd;
  g_io.sq_pending = 0;

  // Map SQ ring
  size_t sq_ring_size =
    params.sq_off.array + params.sq_entries * sizeof(uint32_t);
  void *sq_ptr = mmap(
    NULL, sq_ring_size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_POPULATE, fd,
    IORING_OFF_SQ_RING
  );
  if (sq_ptr == MAP_FAILED)
    abort();

  g_io.sq_head = (uint32_t *)((char *)sq_ptr + params.sq_off.head);
  g_io.sq_tail = (uint32_t *)((char *)sq_ptr + params.sq_off.tail);
  g_io.sq_ring_mask = (uint32_t *)((char *)sq_ptr + params.sq_off.ring_mask);
  g_io.sq_ring_entries =
    (uint32_t *)((char *)sq_ptr + params.sq_off.ring_entries);
  g_io.sq_array = (uint32_t *)((char *)sq_ptr + params.sq_off.array);

  // Map SQEs
  size_t sqes_size = params.sq_entries * sizeof(struct io_uring_sqe);
  void *sqes_ptr = mmap(
    NULL, sqes_size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_POPULATE, fd,
    IORING_OFF_SQES
  );
  if (sqes_ptr == MAP_FAILED)
    abort();

  g_io.sqes = (struct io_uring_sqe *)sqes_ptr;

  // Map CQ ring
  size_t cq_ring_size =
    params.cq_off.cqes + params.cq_entries * sizeof(struct io_uring_cqe);
  void *cq_ptr = mmap(
    NULL, cq_ring_size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_POPULATE, fd,
    IORING_OFF_CQ_RING
  );
  if (cq_ptr == MAP_FAILED)
    abort();

  g_io.cq_head = (uint32_t *)((char *)cq_ptr + params.cq_off.head);
  g_io.cq_tail = (uint32_t *)((char *)cq_ptr + params.cq_off.tail);
  g_io.cq_ring_mask = (uint32_t *)((char *)cq_ptr + params.cq_off.ring_mask);
  g_io.cq_ring_entries =
    (uint32_t *)((char *)cq_ptr + params.cq_off.ring_entries);
  g_io.cqes = (struct io_uring_cqe *)((char *)cq_ptr + params.cq_off.cqes);

  g_io_initialized = 1;
}

// -- submission helpers --

static struct io_uring_sqe *
get_sqe(void) {
  io_init();

  uint32_t tail = *g_io.sq_tail;
  uint32_t head = atomic_load_explicit(
    (_Atomic uint32_t *)g_io.sq_head, memory_order_acquire
  );
  uint32_t mask = *g_io.sq_ring_mask;

  if (tail - head >= *g_io.sq_ring_entries) {
    // SQ full — flush pending submissions and retry
    io_uring_enter(g_io.ring_fd, g_io.sq_pending, 0, 0, NULL, 0);
    g_io.sq_pending = 0;
    head = atomic_load_explicit(
      (_Atomic uint32_t *)g_io.sq_head, memory_order_acquire
    );
    if (tail - head >= *g_io.sq_ring_entries)
      abort();
  }

  uint32_t index = tail & mask;
  g_io.sq_array[index] = index;

  struct io_uring_sqe *sqe = &g_io.sqes[index];
  memset(sqe, 0, sizeof(*sqe));

  *g_io.sq_tail = tail + 1;
  atomic_thread_fence(memory_order_release);
  g_io.sq_pending++;

  return sqe;
}

// -- public API --

void
moonbit_co_io_submit_open(
  const char *path,
  int32_t flags,
  int32_t mode,
  void *task
) {
  struct io_uring_sqe *sqe = get_sqe();
  sqe->opcode = IORING_OP_OPENAT;
  sqe->fd = AT_FDCWD;
  sqe->addr = (uint64_t)(uintptr_t)path;
  sqe->len = (uint32_t)mode;
  sqe->open_flags = (uint32_t)flags;
  sqe->user_data = (uint64_t)(uintptr_t)task;
}

void
moonbit_co_io_submit_read(
  uint64_t handle,
  void *bytes,
  int32_t length,
  void *task
) {
  struct io_uring_sqe *sqe = get_sqe();
  sqe->opcode = IORING_OP_READ;
  sqe->fd = (int32_t)handle;
  sqe->addr = (uint64_t)(uintptr_t)bytes;
  sqe->len = (uint32_t)length;
  sqe->off = (uint64_t)-1; // use current file offset
  sqe->user_data = (uint64_t)(uintptr_t)task;
}

void
moonbit_co_io_submit_write(
  uint64_t handle,
  void *bytes,
  int32_t length,
  void *task
) {
  struct io_uring_sqe *sqe = get_sqe();
  sqe->opcode = IORING_OP_WRITE;
  sqe->fd = (int32_t)handle;
  sqe->addr = (uint64_t)(uintptr_t)bytes;
  sqe->len = (uint32_t)length;
  sqe->off = (uint64_t)-1; // use current file offset
  sqe->user_data = (uint64_t)(uintptr_t)task;
}

void
moonbit_co_io_submit_close(uint64_t handle, void *task) {
  struct io_uring_sqe *sqe = get_sqe();
  sqe->opcode = IORING_OP_CLOSE;
  sqe->fd = (int32_t)handle;
  sqe->user_data = (uint64_t)(uintptr_t)task;
}

void
moonbit_co_io_poll(
  void **tasks,
  uint64_t *values,
  int32_t *errors,
  int32_t *length,
  int64_t timeout
) {
  io_init();

  // Flush any pending submissions and wait for at least one completion
  int flags = IORING_ENTER_GETEVENTS;
  int ret;
  do {
    ret = io_uring_enter(g_io.ring_fd, g_io.sq_pending, 1, flags, NULL, 0);
  } while (ret < 0 && errno == EINTR);
  if (ret < 0)
    abort();
  g_io.sq_pending = 0;

  // Drain completions
  uint32_t head = *g_io.cq_head;
  uint32_t tail = atomic_load_explicit(
    (_Atomic uint32_t *)g_io.cq_tail, memory_order_acquire
  );
  uint32_t mask = *g_io.cq_ring_mask;

  int32_t count = 0;
  while (head != tail) {
    struct io_uring_cqe *cqe = &g_io.cqes[head & mask];

    tasks[count] = (void *)(uintptr_t)cqe->user_data;
    if (cqe->res >= 0) {
      values[count] = (uint64_t)cqe->res;
      errors[count] = 0;
    } else {
      values[count] = 0;
      errors[count] = -cqe->res; // positive errno
    }
    count++;
    head++;
  }

  atomic_store_explicit(
    (_Atomic uint32_t *)g_io.cq_head, head, memory_order_release
  );

  *length = count;
}
