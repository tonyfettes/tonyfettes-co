#ifndef MOONBIT_CO_IO_H

#include <moonbit.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_open(
  const char *path,
  int32_t flags,
  int32_t mode,
  void *task
);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_read(
  uint64_t handle,
  void *bytes,
  int32_t length,
  void *task
);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_write(
  uint64_t handle,
  void *bytes,
  int32_t length,
  void *task
);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_submit_close(uint64_t handle, void *task);

MOONBIT_FFI_EXPORT
void
moonbit_co_io_poll(
  void **tasks,
  uint64_t *values,
  int32_t *errors,
  int32_t *length,
  int64_t timeout
);

#endif // MOONBIT_CO_IO_H
