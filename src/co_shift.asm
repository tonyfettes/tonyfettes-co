; moonbit_co__shift(from, to)
; Win64 ABI: rcx=from, rdx=to

_TEXT SEGMENT

moonbit_co__shift PROC
  ; Save callee-saved registers into from
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

  ; Load callee-saved registers from to
  mov rsp, [rdx]
  mov rbp, [rdx+8]
  mov rbx, [rdx+16]
  mov r12, [rdx+24]
  mov r13, [rdx+32]
  mov r14, [rdx+40]
  mov r15, [rdx+48]
  mov rax, [rdx+56]
  mov [rsp], rax
  ; Restore Win64 extra callee-saved registers
  mov rdi, [rdx+64]
  mov rsi, [rdx+72]
  movdqu xmm6, [rdx+80]
  movdqu xmm7, [rdx+96]
  movdqu xmm8, [rdx+112]
  movdqu xmm9, [rdx+128]
  movdqu xmm10, [rdx+144]
  movdqu xmm11, [rdx+160]
  movdqu xmm12, [rdx+176]
  movdqu xmm13, [rdx+192]
  movdqu xmm14, [rdx+208]
  movdqu xmm15, [rdx+224]

  ret
moonbit_co__shift ENDP

_TEXT ENDS
END
