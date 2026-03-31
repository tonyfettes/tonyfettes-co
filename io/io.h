#ifndef MOONBIT_CO_IO_H
#define MOONBIT_CO_IO_H

#include <moonbit.h>
#include <stdint.h>

struct moonbit_co_io;

MOONBIT_FFI_EXPORT
struct moonbit_co_io *
moonbit_co_io_create(void);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_open(
  struct moonbit_co_io *io,
  const char *path,
  int32_t flags,
  int32_t mode,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_read(
  struct moonbit_co_io *io,
  uint64_t handle,
  void *bytes,
  int32_t length,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_write(
  struct moonbit_co_io *io,
  uint64_t handle,
  void *bytes,
  int32_t length,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_close(
  struct moonbit_co_io *io,
  uint64_t handle,
  uint64_t *value,
  int32_t *error,
  void *task
);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_poll(
  struct moonbit_co_io *io,
  void **tasks,
  int32_t *count,
  int64_t timeout
);

#endif // MOONBIT_CO_IO_H
