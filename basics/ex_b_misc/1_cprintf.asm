;-------------------------------------------------------------------------
; 1_cprintf.asm
;
; Use printf (variadic func) to print a string and a number
; See readme.md -> 🔀 1. Calling convention -> C. Variadic functions
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 1_cprintf.asm && gcc 1_cprintf.o -o 1_cprintf.bin
;-------------------------------------------------------------------------

; `extern` tells the assembler that the `printf` label is defined in another
; object file or library. The linker will resolve this address at link time.
extern printf

; Data Section
section .data 
    ; The format string for printf.
    ; %s expects a pointer to a string.
    ; %d expects an integer value.
    ; 0xA is the newline character.
    ; The final `0` is the null terminator, which is required for C strings.
    fmt_str: db  "The string is: %s and number is: %d", 0xA, 0

    ; The string argument to be passed to printf.
    ; This must also be null-terminated.
    arg_str: db  "Hello World!", 0
    arg_num: dw  25

; Code Section
section .text
global main
main: 
    ; Standard prologue for System V AMD64 ABI compliance. 
    ; (See the project `readme.md` for a detailed explanation).
    push rbp
    mov rbp, rsp

    ; Prepare arguments for calling the C function: printf(fmt_str, arg_str, 21).
    ; We follow the System V AMD64 ABI for function arguments.
    mov rdi, fmt_str    ; arg1: pointer to the format string
    mov rsi, arg_str    ; arg2: pointer to the string for %s
    mov rdx, [arg_num]  ; arg3: integer value for %d, arg_num is the address
                        ; and [arg_num] is it's value
    ; Special requirement for variadic functions (like printf) in the ABI:
    ; The `rax` register must be set to the number of floating-point arguments
    ; passed in XMM registers. Since we are not passing any floating-point
    ; arguments, we must set rax to 0.
    mov rax, 0

    ; call printf, make sure that stack is 16-byte aligned (ABI requirement).
    ; The C runtime ensures the stack is 16-byte aligned before calling main.
    ; But the `call` instruction pushes an 8-byte return address, making the stack
    ; unaligned. We re-aligned the stack by `push rbp` in the prologue. 
    call printf       

    ; Standard epilogue
    leave
    ; exit (0)
    mov rax, 60 ; sys_exit
    mov rdi, 0  ; exit_code
    syscall     