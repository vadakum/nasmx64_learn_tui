;-------------------------------------------------------------------------
; first_ld.asm
;
; A Minimal program - for x86_64 (will run on 64-bit linux only). 
; This version is linked directly with 'ld', the GNU linker.
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 first_ld.asm && ld first_ld.o -o first_ld.bin
; 
; Run:
; > ./first_ld.bin
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
;
; `global` makes the `_start` label visible to the linker.
; `_start` is the default entry point that the linker (ld) looks for.
; The operating system transfers control directly to our `_start` label.
global _start
_start: 
    ; This is the entry point for our code when linked with ld.
    
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
    ; We must manually tell the kernel to terminate our process using the 
    ; `sys_exit` syscall
    mov rax, 60  ; rax = syscall number (`sys_exit` = 60).
    mov rdi, 21  ; rdi = program's exit code.
    syscall      ; Transfer control to the kernel to execute the syscall.
