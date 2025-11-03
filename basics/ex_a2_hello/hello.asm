;-------------------------------------------------------------------------
; hello.asm
;
; Use `syscall` call to print a string (I/O).
; See readme.md -> 🔀 1. Calling convention -> B. System Calls
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 hello.asm && gcc hello.o -o hello.bin
;-------------------------------------------------------------------------

; Data Section
section .data 
    ; `db` means `declare byte`. We are defining a sequence of bytes that form our string.
    ; 0xA is the ASCII code for a newline character, which moves the cursor to the next line.
    msg:  db "Hello World (nasm x64) !", 0xA
    .LEN: equ $-msg   ; - `.LEN` is a local label, it is associated with the previous non-local
                     ;    label and we can access it as `msg.LEN` 
                     ; - `equ` means `equate`. It defines a constant. 
                     ; - `$` represents the current address and `msg` is the address where 
                     ;   the message starts. `$-msg` calculates the length of the message 
                     ;   by subtracting the start address from the current address.
; Code Section
section .text
global main 
main: 
    ; Standard prologue for System V AMD64 ABI compliance. 
    ; (See the project `readme.md` for a detailed explanation).
    push rbp
    mov rbp, rsp

    ; To print to the console, we ask the Linux kernel to do it for us using a `syscall`.
    ; We need to set up specific registers with the correct arguments for the `write` syscall.
    ; For more details refer to:
    ; Project readme.md -> 🔀 1. Calling convention -> B. System Calls

    ;
    ; syscall
    ;
    mov rax, 1        ; syscall number for `sys_write` is 1.
    mov rdi, 1        ; file descriptor 1 is STDOUT (standard output, i.e., the console).
    mov rsi, msg      ; the address of the message we want to write.
    mov rdx, msg.LEN  ; the number of bytes to write from the buffer.
    syscall           

    ; Standard epilogue
    leave
    ; Exit
    mov rax, 60 ; rax = syscall number (`sys_exit` = 60).
    mov rdi, 0  ; rdi = program's exit code.
    syscall     

 
