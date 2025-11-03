;-------------------------------------------------------------------------
; 3_addressing.asm
;
; Addressing Modes in x86-64 (NASM Syntax)
;
; Access and manipulate data using x86-64 addressing modes.
;
; 1. Immediate Addressing Mode:
; The data value is encoded directly within the instruction.
; add rbx, 100    ; adds the constant value 100 (0x64) to the rbx register
; mov rcx, 0xFACE ; sets rcx to the constant hexadecimal value 0xFACE
;
; 2. Register Addressing Mode:
; Operands are specified by their register names.
; mov rbx, rax    ; copies the 64-bit (8 byte) value from rax to rbx
; mov al, bl      ; copies the 8-bit (1 byte) value from bl to al
;
; 3. Memory Addressing Modes (Base-Index-Scale-Displacement):
; The address calculation follows the general formula: 
; [ Base Register + (Index Register * Scale) + Displacement ]
; Where Scale can be 1, 2, 4, or 8 and 
;       Displacement is a constant offset (symbolic or numeric).
; The Square brackets [] denote a memory operand in NASM, which causes 
; the CPU to dereference the calculated address (retrieve the value 
; at calculated memory address). However there is an exception, when `lea` 
; (load effective address) instruction is used. In this case CPU performs 
; an address calculation only (dereferencing is skipped).
;
; ------------------
; Common Variations:
; ------------------
;
; a) Simple Register Indirect Addressing:
;    Copy the qword at the address pointed to by rsi into rax
;    mov rax, [rsi] 
;
; b) Displacement (Base-Relative) Addressing:
;    Copy the qword at the address (value of rsi minus 8) into rax
;    mov rax, [rsi - 8] 
;
; c) Symbolic Displacement (Variable Access):
;    Copy the 3rd byte (offset 2) from the address of 'my_str' into al
;    mov al, byte [my_str + 2] 
;
; d) Full Base-Index-Scale-Displacement:
;    Copy the byte at address rax + (rsi * 2) + 16 into al
;    mov al, byte [rax + rsi * 2 + 10h] 
;
; 4. Relative (RIP-Relative) and Absolute Addressing:
;
; RIP-Relative addressing supports Position-Independent Code (pic), which 
; is required by dynamic linkers for shared libraries and executables.
;
; RIP-Relative Addressing (`[rip + offset]`):
; The address is calculated by adding a signed offset (Displacement)
; to the current Instruction Pointer `rip`. This is mandatory for `pic`.
; mov rax, [rel my_label]   ; forces RIP-relative addressing.
;
; Absolute Addressing (`[full_address]`):
; Uses a fixed, full 64-bit memory address (a constant numerical value). 
; This is generally only used when the code's load address is fixed or known.
; mov rax, [abs my_label]   ; forces absolute addressing.
;
; The DEFAULT Directive:
; Sets the global addressing mode for all `registerless memory operands`
; (i.e., operands that use only a label or constant, not registers like [rax]).
; DEFAULT REL        ; Relative memory access
; DEFAULT ABS        ; Fixed memory access
;
;   Verification using objdump:
;   The output shows the difference in how the address is encoded.
;
;   Source: mov al, [my_str]
;   objdump command example: objdump -d -M intel addressing.o
;
;   objdump output for DEFAULT ABS:
;   0:   8a 04 25 00 00 00 00    mov    al,BYTE PTR ds:0x0
;   (We can see an absolute address (0x0) as the offset)
;
;   objdump output for DEFAULT REL:
;   0:   8a 05 00 00 00 00       mov    al,BYTE PTR [rip+0x0]
;   (This explicitly uses the Instruction Pointer `rip` as the base)
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 3_addressing.asm && gcc 3_addressing.o -o 3_addressing.bin
;-------------------------------------------------------------------------

;DEFAULT REL
;DEFAULT ABS

%macro print_string 2
    mov rax, 1    ; sys_write : 1
    mov rdi, 1    ; fd: 1 (stdout)
    mov rsi, %1   ; string address
    mov rdx, %2   ; string length 
    syscall           
%endmacro
%macro print_char 1
    mov rax, 1    ; sys_write : 1
    mov rdi, 1    ; fd: 1 (stdout)
    mov rsi, %1   ; char address
    mov rdx, 1    ; char length 
    syscall           
%endmacro

; Data Section
section .data 
    newline: db 0xA

    str16: db "0123456789ABCDEF" ; 16 bytes
      .LEN equ $-str16
    
    errormsg: db "*** error ***"
        .LEN: equ $-errormsg

section .bss    
    outbuff: resb 18  ; un-initialized buffer of 18 bytes

; Code Section
section .text
global main
main:
    ; Standard prologue for System V AMD64 ABI compliance. 
    ; (See the project `readme.md` for a detailed explanation).
    push rbp
    mov rbp, rsp

    ; 1.
    ; Let's copy 16 byte from str16 to outbuff and print the outbuff.
    ; Note: we can't use someting like `mov [outbuff], [str16]`, most
    ; of the instructions don't take two memory operands. We have to 
    ; get a register involved. 
    mov rax, [str16]       ; copy 8 bytes
    mov [outbuff], rax     ; to outbuff
    mov rax, [str16 + 8]   ; append next 8 bytes
    mov [outbuff + 8], rax ; to outbuff
    ; print outbuff
    print_string outbuff, 16    
    print_char newline

    ; 2.
    ; Change 11th char 'A' to '@' in in outbuff using 
    ; base-index-scale-displacement.
    ; (11th char's offset = 10)
    mov rcx, 10       ; Save the offset
    mov rax, outbuff  ; base 
    mov rsi, 4        ; index 
    ; Load the effective address (calculated address) into rdx, we want
    ; to do a diff between the base address and calculated address to check 
    ; if our calculation is correct.
    lea rdx, [rax + (rsi * 2) + 2]  ; lea into rbx, no dereferencing here 
    ; Verify if our address calculation is correct.
    mov rbx, rdx   ; rbx = rdx and keep rdx safe
    sub rbx, rax   ; rbx = calculated adress - base address
    cmp rbx, rcx   ; Compare rbx with rcx (10)   
    jne .error     ; Jump to .error if rbx != rcx
    ; No error; we can safely use rdx
    mov byte [rdx], '@'  ; Copy `@` into the memory location pointed by rdx
    ; print outbuff
    print_string outbuff, 16
    print_char newline

    ; End of main
    mov rdi, 0 ; success exit code
    jmp .exit

.error:
    print_string errormsg, errormsg.LEN
    print_char newline
    mov rdi, 1 ; failure exit code
    jmp .exit

.exit:
    ; Standard epilogue
    leave
    ; rdi = program's exit code was filled in earlier
    mov rax, 60 ; rax = syscall number (`sys_exit` = 60).
    syscall      
