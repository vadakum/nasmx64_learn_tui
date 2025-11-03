;-------------------------------------------------------------------------
; debug_print_i64.asm
; 
; Prints a 64-bit integer (passed in `rdi`) using C library's printf.
; Preserves: All general-purpose registers (rax, rbx, rcx, rdx, rdi, rsi, 
; rbp, r8-r15) to avoid clobbering of register states
;-------------------------------------------------------------------------
; Usage:
; Include 
; %include "debug_print_i64.asm"
;-------------------------------------------------------------------------

extern printf

; Data Section
section .data 
    fmt db "debug: num=%ld  ", 0xA, 0

; Code Section
section .text
global debug_print_i64
; Function: debug_print_num
; Args:
;   rdi: number to print
debug_print_i64:
    push rbp
    mov rbp, rsp
    ; Preserve the caller's environment
    ; To guarantee no clobbering, we must save all registers that printf (a C function)
    ; is permitted to modify (Caller-saved registers), plus any we use for setup.
    ; Caller-saved registers(9): rax, rcx, rdx, rsi, rdi, r8, r9, r10, and r11
    push rax
    push rcx
    push rdx
    push rsi
    push rdi    ; arg
    push r8
    push r9
    push r10
    push r11    ; Stack is 16 byte aligned.
    ; We have pushed 10 registers on the stack, 10 * 8 bytes = 80 bytes 
    ; is a multiple of 16. 
    ; Prepare printf
    mov rsi, rdi      ; 2nd argument
    mov rdi, fmt      ; 1st argument: format string
    mov rax, 0        ; Per ABI, 0 float args in xmm regs
    call printf
    ; Restore the registers
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ; Cleanup
    leave
    ret
