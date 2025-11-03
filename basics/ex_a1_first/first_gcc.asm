;-------------------------------------------------------------------------
; first_gcc.asm
;
; A Minimal program - for x86_64 (will run on 64-bit linux only). 
; This version is linked with gcc, which includes the C runtime.
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 first_gcc.asm && gcc first_gcc.o -o first_gcc.bin
; 
; Run:
; > ./first_gcc.bin
; > echo $?
; 21
;-------------------------------------------------------------------------

; Data Section
section .data 
; This section is for initialized data, such as constants and strings,
; that are defined at compile time.

; BSS Section
section .bss    
; This section is for uninitialized data. Space is reserved here for
; variables that will be initialized at runtime.


; Code Section
section .text
; `global` makes the `main` label visible to the linker.
; When linking with gcc, the C runtime library (CRT) is included. The CRT's 
; own entry point (_start) performs some setup and then calls our `main` 
; function.
global main
main: 
    ; This is the entry point for our code when linked with gcc.
    
    ; Standard prologue for System V AMD64 ABI compliance. 
    ; (See the project `readme.md` for a detailed explanation).
    push rbp
    mov rbp, rsp

    ; Program Logic...


    ; Standard epilogue
    ; The `leave` instruction is equivalent to `mov rsp, rbp; pop rbp`.
    ; It deallocates local variables and restores the caller's stack frame.
    leave

    ; Exit
    ; We will exit with an arbitrary code of 21 (0 typically means success).
    ; This is done by making a direct system call to the kernel.
    mov rax, 60  ; rax = syscall number (`sys_exit` = 60).
    mov rdi, 21  ; rdi = program's exit code.
    syscall      ; Transfer control to the kernel to execute the syscall.

    ; --- Alternative Exit Method ---
    ; When linking with gcc, we can simply return from `main`. The C runtime
    ; will then call `exit()` using the value in `rax` as the exit code.
    ; The `syscall` approach is more explicit, but `ret` is also valid.
    ; A `ret` from `main` can be less clear, as it looks like a normal
    ; function return rather than a program termination.
    ;
    ; mov rax, 21 
    ; ret
