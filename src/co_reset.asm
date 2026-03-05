; moonbit_co__reset(ctx, stack_top, func, arg)
; Win64 ABI: rcx=ctx, rdx=stack_top, r8=func, r9=arg

_TEXT SEGMENT

moonbit_co__reset PROC
  ; Save callee-saved registers into ctx
  mov [rcx], rsp
  mov [rcx+8], rbp
  mov [rcx+16], rbx
  mov [rcx+24], r12
  mov [rcx+32], r13
  mov [rcx+40], r14
  mov [rcx+48], r15
  ; Save return address
  mov rax, [rsp]
  mov [rcx+56], rax
  ; Save Win64 extra callee-saved registers
  mov [rcx+64], rdi
  mov [rcx+72], rsi
  movdqu [rcx+80], xmm6
  movdqu [rcx+96], xmm7
  movdqu [rcx+112], xmm8
  movdqu [rcx+128], xmm9
  movdqu [rcx+144], xmm10
  movdqu [rcx+160], xmm11
  movdqu [rcx+176], xmm12
  movdqu [rcx+192], xmm13
  movdqu [rcx+208], xmm14
  movdqu [rcx+224], xmm15

  ; Preserve ctx pointer in a callee-saved register
  mov r12, rcx

  ; Switch to the new stack
  mov rsp, rdx

  ; Allocate 32-byte shadow space (Win64 ABI requirement)
  sub rsp, 32

  ; Call func(arg): rcx=arg (first param on Win64), func is in r8
  mov rcx, r9
  call r8

  ; Restore context from ctx
  mov rsp, [r12]
  mov rbp, [r12+8]
  mov rbx, [r12+16]
  ; r12 restored last since we're using it as ctx pointer
  mov r13, [r12+32]
  mov r14, [r12+40]
  mov r15, [r12+48]
  mov rax, [r12+56]
  mov [rsp], rax
  ; Restore Win64 extra callee-saved registers
  mov rdi, [r12+64]
  mov rsi, [r12+72]
  movdqu xmm6, [r12+80]
  movdqu xmm7, [r12+96]
  movdqu xmm8, [r12+112]
  movdqu xmm9, [r12+128]
  movdqu xmm10, [r12+144]
  movdqu xmm11, [r12+160]
  movdqu xmm12, [r12+176]
  movdqu xmm13, [r12+192]
  movdqu xmm14, [r12+208]
  movdqu xmm15, [r12+224]
  mov r12, [r12+24]

  ret
moonbit_co__reset ENDP

_TEXT ENDS
END
