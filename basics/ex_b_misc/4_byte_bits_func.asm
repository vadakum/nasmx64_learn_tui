;-------------------------------------------------------------------------
; 4_byte_bits_func.asm
;
; Print the bits in a byte
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 4_byte_bits_func.asm && gcc 4_byte_bits_func.o -o 4_byte_bits_func.bin
;-------------------------------------------------------------------------

; Data Section
section .data
    byte_to_print: db 10000101b ; The byte to display

; Code Section
section .text
global main
main:
    ; Standard prologue
    push rbp
    mov rbp, rsp

    movzx edi, byte [byte_to_print] ; Zero-extend to edi, cpu will auto zero-extend into rdi
    call print_byte_bits

    ; Standard epilogue
    leave
    ; Exit
    mov rax, 60            ; sys_exit
    mov rdi, 0             ; exit code 0
    syscall

; Function: print_byte_bits -- prints the 8 bits of a given byte to stdout
; Args:
;   rdi: The value of byte to print (set the lower bits). e.g:
print_byte_bits:
    ; Standard prologue
    push rbp
    mov rbp, rsp

    ; We need a temp 8 byte buffer to store the output, let's use the
    ; stack 
    sub rsp, 16            ; 8 bytes buffer + alignment.
    lea rsi, [rbp - 8]     ; `rsi` will be our pointer to the buffer on the stack.
    mov rcx, 8             ; Loop 8 times for 8 bits.
.loop_conv_bit2byte:
    mov al, dil            ; Copy the byte for bit extraction.
    rol al, 1              ; Rotate the Most Significant Bit into the LSB position.
    mov rdi, rax           ; Store the rotated value back for the next iteration.
    
    and al, 1              ; Isolate the bit (0 or 1).
    add al, '0'            ; Convert to ASCII '0' or '1'.
    
    mov [rsi], al          ; Store the ASCII character in the buffer.
    inc rsi                ; Move to the next position in the buffer.
    
    dec rcx                ; `dec` sets the zf, a `cmp rcx, 0` is not required before jnz.
    jnz .loop_conv_bit2byte 
    ; System call to write the buffer to stdout
    mov rax, 1             ; sys_write
    mov rdi, 1             ; File descriptor 1 (stdout).
    lea rsi, [rbp - 8]     ; Address of the start of the buffer.
    mov rdx, 8             ; Length of the buffer.
    syscall
    ; Standard epilogue
    leave 
    ret
