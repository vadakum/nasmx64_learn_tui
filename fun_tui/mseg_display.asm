;-------------------------------------------------------------------------
; mseg_display.asm
;
; Multi-segment display (8 segments) to render digits
; as a multi-character (multi-column) ASCII representation.
; We will use:
;   - Table-driven rendering using bit masks
;   - Index arithmetic for a simple framebuffer (memlayout)
;
; Output:
;  ###    |        | ###    | ###    |        | ###    | ###    | ###    | ###    | ###    |
; #   #   |    #   |    #   |    #   |#   #   |#       |#       |    #   |#   #   |#   #   |
;         |    #   | ###    | ###    | ####   | ###    | ###    |    #   | ###    | ###    |
; #   #   |    #   |#       |    #   |    #   |    #   |#   #   |    #   |#   #   |    #   |
;  ###    |        | ###    | ###    |        | ###    | ###    |        | ###    | ###    |
;
; Layout (rows x columns):
;                                        | Position of segment in a byte.
;                                        | Bits 2,1 and 0 are not used.   
; Byte  1   2     3    4      5          |    76543210   (bit location)
; row1      ###   ###          ###       |     --- <--- a  
; row2  #      #     # #   #  #   #      | f->|   |<--- b                                  
; row3  #   ###   ###   ####   ###       | g-> ---|<--- *h 
; row4  #  #         #     #  #   #      | e->|   |<--- c                                     
; row5      ###   ###          ###       | d-> ---      
;                                        | (*h : Visual clarity for 1, 4 and 7)
; 
; The segments (a to h) of a digit are displyed on specific row 
; (e.g., f and b of digit 4 on row1, g of digit 2 on row3 etc.)
; To print a digit using segments, we require information of the row number and 
; the bit pattern for each segment.
;
; All the required info on segments like mapping of digit to it's segments,
; test masks (test segment is on or off), output bit pattern (result) 
; and the row number in the framebuffer and output
; are encoded in `seg_disp`.
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 mseg_display.asm && gcc -g mseg_display.o -o mseg_display.bin
;-------------------------------------------------------------------------
%macro print_char 1
    mov rax, 1       ; sys_write
    mov rdi, 1       ; stdout fd
    mov rsi, %1      ; address of the char
    mov rdx, 1       ; length = 1
    syscall
%endmacro

; Data Section
section .data 
    seg_disp:
        ; bits: hgfedcba (for each digit 0-9)
        ; lower bits (0-7) used; bits 0..2 (LSBs) unused for visual spacing
        .bits:
            db 00111111b, ; 0 -> a,b,c,d,e,f
            db 10000110b, ; 1 -> b,c,h
            db 01011011b, ; 2 -> a,b,d,e,g
            db 01001111b, ; 3 -> a,b,c,d,g
            db 11100110b, ; 4 -> b,c,f,g
            db 01101101b, ; 5 -> a,c,d,f,g
            db 01111101b, ; 6 -> a,c,d,e,f,g
            db 10000111b, ; 7 -> a,b,c,h
            db 01111111b, ; 8 -> a,b,c,d,e,f,g
            db 01101111b  ; 9 -> a,b,c,d,f,g

        ; masks used to test if a segment is present in seg_disp.bits[digit]
        .testmasks: 
            db 00000001b, ; a
            db 00000010b, ; b
            db 00000100b, ; c
            db 00001000b, ; d
            db 00010000b, ; e
            db 00100000b, ; f
            db 01000000b, ; g
            db 10000000b  ; h

        ; result masks - how that segment maps into the byte for a particular
        ; row/column cell in memlayout (3-wide segments represented using
        ; consecutive character positions).
        .resultmasks: 
                db 01110000b, ; a (3 chars)
                db 00001000b, ; b (1 char)
                db 00001000b, ; c (1 char)
                db 01110000b, ; d (3 chars)
                db 10000000b, ; e (1 char at MSB)
                db 10000000b, ; f (1 char)
                db 01110000b, ; g (3 chars)
                db 00001000b, ; h (1 char)

        .rowidx: 
                db 0, ; a -> row 0
                db 1, ; b -> row 1
                db 3, ; c -> row 3
                db 4, ; d -> row 4
                db 3, ; e -> row 3
                db 1, ; f -> row 1
                db 2, ; g -> row 2
                db 2  ; h -> row 2
                
        .SEGMENT_COUNT: equ 8

    input_digits:
            db 0,1,2,3,4,5,6,7,8,9
            .SZ equ $ - input_digits

    bit_on_char     equ '#'
    bit_off_char    equ ' '

    str_delim       db '|'
    str_newline     db 0xA
    
; BSS Section
section .bss 
    ; framebuffer
    memlayout: 
        .rows:      resb 50  
        .COL_SZ:    equ 10
        .ROW_SZ:    equ 5

; Code Section
section .text
global main
main: 
    push rbp
    mov rbp, rsp

    ; Save the callee-saved register (inside main the C runtime is the
    ; caller and this current main function is a callee).
    ; As per System V AMD64 ABI, if we modify any of these registers
    ; `rbx, rbp, r12, r13, r14, r15` theh they should be restored back 
    ; before the function returns.
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; Keep the stack aligned (16 bytes).
    ; Stack is preallocated and grows down.
    sub rsp, 8  
                
    ; Loop through digits (rbx = column)
    xor rbx, rbx          ; rbx = 0

.loop_process_digits:
    movzx eax, byte [input_digits + rbx]   ; rax = digit, `movzx eax,`: cpu auto zero-extends into rax
    ; Get segments bits of the current digit
    movzx r12d, byte [seg_disp.bits + rax] ; r12 = segment.bits[digit]

    ; Loop through the segments `a to h`, index 0 to seg_disp.SEGMENT_COUNT
    xor r13, r13                          ; Start, r13 = segment index, its the table index 
                                          ; for seg_disp(.testmasks,.resultmasks`and `seg_disp.rowidx`)
.loop_process_segments:     
    ; Load the test mask (byte -> zero-extended) and AND with r12
    movzx ecx, byte [seg_disp.testmasks + r13] ; rcx = testmask
    and rcx, r12       ; rcx = (digit segment bits & testmask) 
    test rcx, rcx      ; Set flags based on rcx (zf will be set if rcx is 0)
    setnz al           ; If rcx is not zero, set al to 1 else it remains 0
    
    ; Prepare the applicable result mask. 
    ; if (al == 0) applicable_result_mask = 0;
    ; else applicable_result_mask = seg_disp.resultmasks[r13];
    ; We can do this using bitwise instructions:
    ; Spread the LSB bit in `al` i.e, fill `al` byte with either 0s or 1s.
    ; Then AND with seg_disp.resultmasks[segment index]
    neg al                           ; Apply two's complement negation 
                                     ; If al was 0 it stays 0, if it was 0x01, it becomes 0xFF
    and al, [seg_disp.resultmasks + r13]
    movzx r14d, al                    ; Save the result mask in r14
    
    ; Calculate address of the byte in the framebuffer (memlayout) 
    ;  - byte addr = address of starting row + column 
    ;  - address of starting row = seg_disp.rowidx[ r13 ] * COL_SZ
    ;  - column = rbx (digit index)  
    ;  byte addr = memlayout.rows[ (seg_disp.rowidx[ r13 ] * COL_SZ) + rbx ]

    movzx eax, byte [seg_disp.rowidx + r13] ; rax = seg_disp.rowidx[ r13 ]
    mov r15, memlayout.COL_SZ               ; r15 = COL_SZ   
    mul r15                                 ; rax = seg_disp.rowidx[ r13 ] * COL_SZ
    add rax, rbx                            ; rax = (seg_disp.rowidx[ r13 ] * COL_SZ) + rbx 
    lea r15, [memlayout.rows + rax]         ; Reuse r15, save the effective memory address

    ; OR the result mask (lower byte) into the target framebuffer byte
    or byte [r15], r14b     ; r14b gives access to the lower byte of r14
    
    ; Inner loop for segments
    inc r13
    cmp r13, seg_disp.SEGMENT_COUNT
    jl .loop_process_segments

    ; Outer loop for num digits
    inc rbx
    cmp rbx, input_digits.SZ
    jl .loop_process_digits

    ; Print the layout
    call print_layout

    ; Restore callee-saved registers. 
    ; First, reverse the stack alignment.
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx

    leave
    ; exit(0)
    xor rdi, rdi
    mov rax, 60
    syscall      

; Function: print_layout -- print rows x cols, each byte expanded 
;           into ASCII characters
; Args: 
;   None
print_layout:
    push rbp
    mov  rbp, rsp

    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8      ; align the stack

    xor rbx, rbx    ; row index = 0

.loop_rows:
    xor r14, r14    ; col index = 0

.loop_cols:
    ; Compute offset = (rbx * COL_SZ) + r14
    mov rax, rbx
    mov r15, memlayout.COL_SZ 
    mul r15                 ; rax = rbx * COL_SZ
    add rax, r14            ; rax += col index

    ; Load the framebuffer byte (explicit byte-sized load)
    movzx edi, byte [memlayout.rows + rax] ; rdi (arg1) = byte value to print
    call print_byte_bits 

    print_char str_delim

    ; Inner loop cols
    inc r14
    cmp r14, memlayout.COL_SZ
    jl .loop_cols

    print_char str_newline

    ; Outer loop rows
    inc rbx
    cmp rbx, memlayout.ROW_SZ
    jl .loop_rows

    ; Restore callee-saved registers. 
    ; First, reverse the stack alignment.
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx

    leave
    ret

; Function: print_byte_bits -- prints the 8 bits of a given byte to stdout
; Args:
;   rdi: The value of byte to print (set the lower bits).
print_byte_bits:
    push rbp
    mov rbp, rsp

    sub rsp, 16        ; 8 bytes buffer + alignment

    lea rsi, [rbp - 8] ; rsi will be our pointer to the buffer on the stack
    mov r8, rdi        ; Save byte into r8, rdi will be reused later
    
    mov rcx, 8         ; Loop 8 times for 8 bits
    xor rax, rax       ; Clear rax, as we will be copying only lower byte

loop_conv_bit2byte:
    mov al, r8b    ; Copy the byte for bit extraction
    rol al, 1      ; Rotate the Most Significant Bit into the LSB position
    mov r8b, al    ; Store the rotated value back for the next iteration
    and al, 1      ; Isolate the bit (0 or 1)

    movzx edi, al  ; Copy al and zero extend rdi  
    call get_bit_on_off_char  ; Returns char in al

    mov [rsi], al  ; Store the ASCII character in the buffer
    inc rsi        ; Move to the next position in the buffer

    dec rcx                ; Decrement bit counter, zf is updated
    jnz loop_conv_bit2byte ; 

    ; Write the 8-byte buffer
    mov rax, 1
    mov rdi, 1
    lea rsi, [rbp - 8]
    mov rdx, 8
    syscall

    leave     
    ret

; Function: get_bit_on_off_char -- returns char for a bit (in al)
; Args:
;    rdi: 0 or 1
; Return:
;    al: char
get_bit_on_off_char:
    push rbp
    mov rbp, rsp

    cmp rdi, 1
    je .set_bit_on_char   ;if 
.set_bit_off_char:        ;else
    mov rax, bit_off_char
    jmp .done
.set_bit_on_char:
    mov rax, bit_on_char
    jmp .done
.done:    
    leave
    ret

