;-------------------------------------------------------------------------
; 2_instr.asm
;
; Use basic CPU instructions:
;   Math    : add, sub, mul, div
;   IncDec  : inc, dec
;   Bitwise : and, or, neg, not, xor, shl, shr
; Use NASM macros for printf (variadic func) 
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 2_instr.asm && gcc 2_instr.o -o 2_instr.bin
;-------------------------------------------------------------------------

; Macros to simplify calling printf for our examples.
; printf call with 4 arguments.
%macro printf_4 4
    mov rdi, %1     ; 1st argument: format string
    mov rsi, %2     ; 2nd argument
    mov rdx, %3     ; 3rd argument
    mov rcx, %4     ; 4th argument (the result)
    mov rax, 0      ; Per ABI, 0 float args in xmm regs
    call printf
%endmacro
; printf call with 3 arguments.
%macro printf_3 3
    mov rdi, %1     ; 1st argument: format string
    mov rsi, %2     ; 2nd argument
    mov rdx, %3     ; 3rd argument (the result)
    mov rax, 0      ; Per ABI, 0 float args in xmm regs
    call printf
%endmacro

extern printf

; Data Section
section .data 
    ; allocate memory for messages 
    ; they will be passed to printf 
    add_msg: db "=> add: %d + %d = %d", 0xA, 0
    sub_msg: db "=> sub: %d - %d = %d", 0xA, 0
    mul_msg: db "=> mul: %d * %d = %d", 0xA, 0
    div_msg: db "=> div: %d / %d = %d", 0xA, 0
    
    and_msg: db "=> and: %d & %d = %d", 0xA, 0
    or_msg:  db "=> or: %d | %d = %d", 0xA, 0
    xor_msg: db "=> xor: %d ^ %d = %d", 0xA, 0
    shl_msg: db "=> shl: %d << %d = %d", 0xA, 0
    shr_msg: db "=> shr: %d >> %d = %d", 0xA, 0

    inc_msg: db "=> inc: %d -> %d", 0xA, 0
    dec_msg: db "=> dec: %d -> %d", 0xA, 0

    neg_msg: db "=> neg: %d -> %d", 0xA, 0
    not_msg: db "=> not: %d -> %d", 0xA, 0

    ; constants, similar to #define in C
    C_ADD_1 equ 100  
    C_ADD_2 equ 200

    C_SUB_1 equ 200000
    C_SUB_2 equ 1
    
    C_MUL_1 equ 7
    C_MUL_2 equ 5
    
    C_DIV_1 equ 100
    C_DIV_2 equ 3
    
    C_AND_1 equ 3
    C_AND_2 equ 2
    
    C_OR_1 equ 3
    C_OR_2 equ 2
    
    C_XOR equ 0x1111
    
    C_SHL equ 1         ; shift value
    C_SHL_BITS equ 4    ; bits to shift
    C_SHR equ 32        ; shift value
    C_SHR_BITS equ 4    ; bits to shift

    C_INC equ 10
    C_DEC equ 10
    C_NEG equ 10
    C_NOT equ -1 

; Code Section
section .text
global main     
main: 
    ; Standard prologue for System V AMD64 ABI compliance. 
    ; (See the project `readme.md` for a detailed explanation).
    push rbp
    mov rbp, rsp

    ;=== add ===
    ; Adds the source operand to the destination operand.
    ; Result is stored in the destination operand (rax).
    mov rax, C_ADD_1
    mov rbx, C_ADD_2
    add rax, rbx  ; result rax += rbx
    printf_4 add_msg, C_ADD_1, C_ADD_2, rax

    ;=== sub ===
    ; Subtracts the source operand from the destination operand.
    ; Result is stored in the destination operand (rax).
    mov rax, C_SUB_1
    mov rbx, C_SUB_2
    sub rax, rbx  ; result rax -= rbx
    printf_4 sub_msg, C_SUB_1, C_SUB_2, rax

    ;=== multiply ===
    ; `mul` performs an unsigned multiplication. It takes one operand.
    ; The other operand is implicitly `rax`.
    ; The 128-bit result is stored in `rdx:rax`.
    mov rax, C_MUL_1
    mov rbx, C_MUL_2
    mul rbx     ; result rdx:rax = rax * rbx
    printf_4 mul_msg, C_MUL_1, C_MUL_2, rax

    ;=== divide ===
    ; `div` performs an unsigned division. It takes one operand (the divisor).
    ; The dividend is implicitly the 128-bit value in `rdx:rax`.
    ; The quotient is stored in `rax`, and the remainder in `rdx`.
    xor rdx, rdx     ; clear rdx for div
    mov rax, C_DIV_1
    mov rbx, C_DIV_2
    div rbx     ; rax = (rdx:rax) / rbx; rdx = remainder
    printf_4 div_msg, C_DIV_1, C_DIV_2, rax

    ; === bitwise and ===
    ; Performs a bitwise AND. The result is stored in the destination operand.
    mov rax, C_AND_1
    mov rbx, C_AND_2
    and rax, rbx
    printf_4 and_msg, C_AND_1, C_AND_2, rax

    ; === bitwise or ===
    ; Performs a bitwise OR.
    mov rax, C_OR_1
    mov rbx, C_OR_2
    or rax, rbx
    printf_4 or_msg, C_OR_1, C_OR_2, rax

    ; === bitwise xor ===
    ; Performs a bitwise exclusive OR. A common use is `xor rax, rax` to clear a register.
    mov rax, C_XOR
    mov rbx, C_XOR
    xor rax, rbx
    printf_4 xor_msg, C_XOR, C_XOR, rax

    ; === bitwise shl ===
    ; Performs a logical left shift. Bits shifted out are lost; zeros are shifted in.
    ; Equivalent to multiplying by 2 for each bit shifted.
    ; The shift instruction expects the shift count to be either an immediate 8-bit value 
    ; or stored in the cl register.
    mov rax, C_SHL
    shl rax, C_SHL_BITS        ; shl rax, rbx or shl rax, bl etc. are not possible
    printf_4 shl_msg, C_SHL, C_SHL_BITS, rax

    ; === bitwise shr ===
    ; Performs a logical right shift. Bits shifted out are lost; zeros are shifted in.
    ; Equivalent to unsigned division by 2 for each bit shifted.
    mov rax, C_SHR
    shr rax, C_SHR_BITS
    printf_4 shr_msg, C_SHR, C_SHR_BITS, rax

    ; === increment ===
    ; Adds 1 to the operand. More efficient than `add rax, 1`.
    mov rax, C_INC
    inc rax
    printf_3 inc_msg, C_INC, rax

    ; === decrement ===
    ; Subtracts 1 from the operand. More efficient than `sub rax, 1`.
    mov rax, C_DEC
    dec rax
    printf_3 dec_msg, C_DEC, rax

    ; === bitwise neg ===
    ; Performs two's complement negation (changes the sign of a number).
    ; Equivalent to inverting all bits and adding 1.
    mov rax, C_NEG
    neg rax
    printf_3 neg_msg, C_NEG, rax

    ; === bitwise not ===
    ; Performs one's complement (inverts all bits).
    mov rax, C_NOT
    not rax
    printf_3 not_msg, C_NOT, rax

    ; Standard epilogue
    leave
    ; Exit
    mov rax, 60 ; rax = syscall number (`sys_exit` = 60).
    mov rdi, 0  ; rdi = program's exit code.
    syscall     