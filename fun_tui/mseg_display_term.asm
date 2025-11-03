;-------------------------------------------------------------------------
; mseg_display_term.asm
;
; A copy of mseg_display.asm with termbox2 support.
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 mseg_display_term.asm && gcc -g mseg_display_term.o -L ./termbox2 -l termbox2 -o mseg_display_term.bin
;-------------------------------------------------------------------------
%include "debug_print_i64.asm"

extern setlocale
extern printf
extern usleep 
;**********************************************************
; termbox2  externs and constants from termbox2/auto_gen_*
;**********************************************************
extern tb_init        ; int tb_init(void)
extern tb_shutdown    ; int tb_shutdown(void)
extern tb_print       ; int tb_print(int x, int y, uint64_t fg, uint64_t bg, const char *str)
extern tb_printf      ; int tb_printf(int x, int y, uint64_t fg, uint64_t bg, const char *fmt, ...)
extern tb_set_cell    ; int tb_set_cell(int x, int y, uint32_t ch, uint64_t fg, uint64_t bg)
extern tb_present     ; int tb_present(void)
extern tb_clear       ; int tb_clear(void)
extern tb_attr_width  ; int tb_attr_width()
extern tb_width       ; int tb_width(void)
extern tb_height      ; int tb_height(void)
extern tb_poll_event  ; int tb_poll_event(void *event)
extern tb_peek_event  ; int tb_peek_event(struct tb_event *event, int timeout_ms)
; Return Code
%define TB_OK                  0
; Colors
%define TB_BLACK               0x0001
%define TB_RED                 0x0002
%define TB_GREEN               0x0003
%define TB_YELLOW              0x0004
%define TB_BLUE                0x0005
%define TB_MAGENTA             0x0006
%define TB_CYAN                0x0007
%define TB_WHITE               0x0008
; Attributes
%define TB_BOLD                0x01000000
%define TB_UNDERLINE           0x02000000
%define TB_REVERSE             0x04000000
%define TB_ITALIC              0x08000000
%define TB_BLINK               0x10000000
%define TB_HI_BLACK            0x20000000
%define TB_BRIGHT              0x40000000
%define TB_DIM                 0x80000000
; Events
%define TB_EVENT_KEY 1
%define TB_EVENT_RESIZE 2
%define TB_EVENT_MOUSE 3
; Keys
%define TB_KEY_ESC             0x1b
%define TB_KEY_ARROW_LEFT      (0xffff - 20)
%define TB_KEY_ARROW_RIGHT     (0xffff - 21)
;**********************************************************

%define PEEK_EVENT_TIMEOUT_MS   2000 ; millisec
%define QUIT_EVENT_LOOP         1   

; Data Section
section .data 
    screen:
        .START_X    equ 10
        .START_Y    equ 5

   ; Locale for unicode support
    locale:
        .arg1       dd 6
        .arg2:      db 0x0

    seg_disp:
        ; Segment bits for digits 0-9 (hgfedcba)
        ; Lower 8 bits (0-7) are used. The 3 LSBs are unused for visual spacing.
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
            db 11101111b  ; 9 -> a,b,c,d,f,g

        ; Masks used to test if a segment is present in seg_disp.bits[digit].
        .testmasks: 
            db 00000001b, ; a
            db 00000010b, ; b
            db 00000100b, ; c
            db 00001000b, ; d
            db 00010000b, ; e
            db 00100000b, ; f
            db 01000000b, ; g
            db 10000000b  ; h

        ; Result masks: Defines how a segment maps to a byte in the memlayout for a specific
        ; row/column cell. 3-wide segments are represented by consecutive character positions.
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

    ; uchar: Unicode characters. Note: these are wider than a byte.
    ; https://en.wikipedia.org/wiki/Block_Elements
    uchar:
        .bit_off    dw 0x0020  ; ' '
        .disp_arr:
                    dw 0x2588, ; █ - Full Block
                    dw 0x2591, ; ░ - Light Shade
                    dw 0x2592, ; ▒ - Medium Shade
                    dw 0x2593, ; ▓ - Dark Shade
                    dw 0x307B  ; ほ - Hiragana Letter Ho
        .DISP_ARR_SIZE    equ ($-uchar.disp_arr) / 2 ; dw size = 2 bytes
    colors:
            dd TB_RED, TB_GREEN, TB_YELLOW, TB_BLUE, TB_MAGENTA, TB_CYAN, TB_WHITE
        .SZ equ ($-colors) / 4 ; dd size = 4 bytes
    fg_attr:
            dd TB_BRIGHT, TB_HI_BLACK
        .SZ equ ($-fg_attr) / 4 ; dd size = 4 bytes

    input_digits:
            db 0,1,2,3,4,5,6,7,8,9
            .SZ equ $ - input_digits

    str_instr:   db "Press ESC key to quit", 0
    str_diagnostic_msg: db "[Info: rand_idx -> disp_arr = %.2d, color = %.2d, fg_attr = %.2d]", 0
   
; BSS Section
section .bss 
    ; framebuffer
    memlayout: 
        .rows:      resb 50  
        .COL_SZ:    equ 10
        .ROW_SZ:    equ 5

    ; Termbox tb_event argument
    tb_event:
        .type_b: resb 1  ; one of  `TB_EVENT_*` constants
        .mod_b:  resb 1  ; bitwise `TB_MOD_*` constants
        .key_w:  resw 1  ; one of  `TB_KEY_*` constants
        .char_d: resd 1  ; a Unicode codepoint
        .w_d:    resd 1  ; resize width
        .h_d:    resd 1  ; resize height
        .x_d:    resd 1  ; mouse x
        .y_d:    resd 1  ; mouse y

    rand_idx_disp_arr: resq 1
    rand_idx_color:      resq 1  
    rand_idx_fg_attr:    resq 1  

; Code Section
section .text
global main
main: 
    push rbp
    mov rbp, rsp

    ; Save the callee-saved registers. Inside main, the C runtime is the
    ; caller and this function is the callee.
    ; As per the System V AMD64 ABI, if we modify any of the registers
    ; `rbx, rbp, r12, r13, r14, r15`, they must be restored before the 
    ; function returns.
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; Keep the stack aligned (16 bytes).
    ; Stack is preallocated and grows down.
    sub rsp, 8  

    call set_locale
    ; Init termbox2
    call tb_init
    ; Loop through digits (rbx = column index)
    xor rbx, rbx          ; rbx = 0
.loop_process_digits:
    movzx eax, byte [input_digits + rbx]   ; rax = digit, `movzx eax,`: cpu auto zero-extends into rax
    ; Get segment bits of the current digit
    movzx r12d, byte [seg_disp.bits + rax] ; r12 = segment.bits[digit]

    ; Loop through the segments 'a' to 'h' (index 0 to seg_disp.SEGMENT_COUNT).
    xor r13, r13                          ; Start, r13 = segment index. This is the table index
                                          ; for seg_disp.testmasks, seg_disp.resultmasks, and seg_disp.rowidx.
.loop_process_segments:     
    ; Load the test mask (byte -> zero-extended) and AND with r12
    movzx ecx, byte [seg_disp.testmasks + r13] ; rcx = testmask
    and rcx, r12       ; rcx = (digit segment bits & testmask) 
    test rcx, rcx      ; Set flags based on rcx (zf will be set if rcx is 0)
    setnz al           ; If rcx is not zero, set al to 1 else it remains 0
    
    ; Prepare the applicable result mask. 
    ; if (al == 0) applicable_result_mask = 0;
    ; else applicable_result_mask = seg_disp.resultmasks[r13];
    ; This can be done using bitwise instructions:
    ; Spread the LSB in `al`, i.e., fill the `al` byte with either all 0s or all 1s.
    ; Then, AND with seg_disp.resultmasks[segment index].
    neg al                           ; Apply two's complement negation. 
                                     ; If al was 0, it stays 0. If it was 0x01, it becomes 0xFF.
    and al, [seg_disp.resultmasks + r13]
    movzx r14d, al                    ; Save the result mask in r14
    
    ; Calculate the address of the byte in the framebuffer (memlayout). 
    ;  - byte addr = address of starting row + column 
    ;  - address of starting row = seg_disp.rowidx[ r13 ] * COL_SZ
    ;  - column = rbx (digit index)  
    ;  byte addr = memlayout.rows[ (seg_disp.rowidx[ r13 ] * COL_SZ) + rbx ]

    movzx eax, byte [seg_disp.rowidx + r13] ; rax = seg_disp.rowidx[ r13 ]
    mov r15, memlayout.COL_SZ               ; r15 = COL_SZ   
    mul r15                                 ; rax = seg_disp.rowidx[ r13 ] * COL_SZ
    add rax, rbx                            ; rax = (seg_disp.rowidx[ r13 ] * COL_SZ) + rbx 
    lea r15, [memlayout.rows + rax]         ; Reuse r15 to save the effective memory address

    ; OR the result mask (lower byte) into the target framebuffer byte.
    or byte [r15], r14b     ; r14b gives access to the lower byte of r14
    
    ; Inner loop for segments
    inc r13
    cmp r13, seg_disp.SEGMENT_COUNT
    jl .loop_process_segments

    ; Outer loop for number of digits
    inc rbx
    cmp rbx, input_digits.SZ
    jl .loop_process_digits


.event_loop:    
    ; Print the layout
    call tb_clear

    call prepare_uchar_properties
    call display_instruction
    call display_diagnostics
    ;mov rdi, rax
    ;call debug_print_i64

    call print_layout
    call tb_present
    
    call handle_events 
    cmp rax, QUIT_EVENT_LOOP
    je .quit
    jmp .event_loop
.quit:
    call tb_shutdown
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

; Function: handle_events
; Args: 
;   None
; Return: 
;   rax = 0 for success, QUIT_EVENT_LOOP if ESC is pressed.    
handle_events:
    push rbp
    mov rbp, rsp

    push rbx    ; Use callee-saved registers.
    sub rsp, 8  ; Align stack to 16 bytes.

    ; Call tb_peek_event with timeout
    mov rdi, tb_event
    mov rsi, PEEK_EVENT_TIMEOUT_MS

    call tb_peek_event ; rax will have result
    cmp rax, TB_OK
    je .check_and_process_event 
    jmp .ret_success
.check_and_process_event:
    cmp byte [tb_event.type_b], TB_EVENT_KEY
    je .process_key_event
    jmp .ret_success
.process_key_event:
    mov ebx, [tb_event.key_w]

    cmp rbx, TB_KEY_ARROW_LEFT  
    je .process_key_arrow_left

    cmp rbx, TB_KEY_ARROW_RIGHT
    je .process_key_arrow_right
    
    cmp rbx, TB_KEY_ESC
    je .process_key_esc

    ; Handle other keys
    jmp .ret_success
.process_key_arrow_left:
    jmp .ret_success
.process_key_arrow_right:
    jmp .ret_success
.process_key_esc:    
    jmp .ret_quit
.ret_success:
    mov rax, 0
    jmp .done
.ret_quit:
    mov rax, QUIT_EVENT_LOOP
    jmp .done
.done:
    ; Cleanup
    add rsp, 8 
    pop rbx
    leave
    ret

; Function: set_locale
; Args:
;   None
set_locale:
    push rbp
    mov rbp, rsp

    mov edi, [locale.arg1]
    mov rsi, locale.arg2
    call setlocale 
    ; Cleanup
    leave
    ret

; Function: prepare_uchar_properties
; Args:
;   None
prepare_uchar_properties:
    push rbp
    mov rbp, rsp
    ; Select a random block character index for printing.
    mov rdi, uchar.DISP_ARR_SIZE
    call get_rand_num
    mov rdi, 2  ; word size
    mul rdi     ; rax = rax * 2
    mov [rand_idx_disp_arr], rax
    ; Select a random color. 
    mov rdi, colors.SZ
    call get_rand_num
    mov rdi, 4  ; dword size
    mul rdi     ; rax = rax * 4
    mov [rand_idx_color], rax
    ; Select a random foreground attribute.
    mov rdi, fg_attr.SZ
    call get_rand_num
    mov rdi, 4  ; dword size
    mul rdi     ; rax = rax * 4
    mov [rand_idx_fg_attr], rax
    ;Cleanup
    leave 
    ret

; Function: display_instruction 
; Args: 
;   None
display_instruction:
    push rbp
    mov rbp, rsp
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rdi, screen.START_X         ; 1. x
    mov rsi, screen.START_Y + 10    ; 2. y
    mov rdx, TB_GREEN | TB_BOLD | TB_UNDERLINE    ; 3. fg
    mov rcx, 0                      ; 4. bg
    mov r8, str_instr               ; 5. String address
    call tb_print
    ; Cleanup
    leave
    ret

; Function: display_diagnostics
; Args: 
;   None
display_diagnostics:
    push rbp
    mov rbp, rsp
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rdi, screen.START_X         ; 1. x
    mov rsi, screen.START_Y + 12    ; 2. y
    mov rdx, TB_WHITE               ; 3. fg
    mov rcx, 0                      ; 4. bg
    mov r8, str_diagnostic_msg      ; 5. String address
    mov r9, [rand_idx_disp_arr]   ; 6. 1st %d
    ; Push remaining arguments onto the stack
    ; (right to left order)
    push qword [rand_idx_fg_attr]   ; 3rd %d
    push qword [rand_idx_color]     ; 2nd %d
    ; Stack is 16 byte aligned
    call tb_printf
    ; Cleanup
    leave
    ret

; Function: print_layout -- Print rows x cols, with each byte expanded 
;           into ASCII characters.
; Args: 
;   None
print_layout:
    push rbp
    mov  rbp, rsp

    push rbx
    push r12
    push r13
    sub rsp, 8      ; Align the stack

    xor rbx, rbx    ; row index = 0
.loop_rows:
    xor r12, r12    ; col index = 0
.loop_cols:
    ; Compute offset = (rbx * COL_SZ) + r12
    mov rax, rbx
    mov r13, memlayout.COL_SZ 
    mul r13                 ; rax = rbx * COL_SZ
    add rax, r12            ; rax += col index

    ; Load the framebuffer byte
    movzx edi, byte [memlayout.rows + rax] ; rdi (arg1) = byte value to print
    mov rsi, rbx                           ; rsi (arg2) = row index
    mov rdx, r12                           ; rdx (arg3) = col index 
    call print_byte_bits 
    
    ; Inner loop cols
    inc r12
    cmp r12, memlayout.COL_SZ
    jl .loop_cols

    ; Outer loop rows
    inc rbx
    cmp rbx, memlayout.ROW_SZ
    jl .loop_rows

    ; Restore callee-saved registers. 
    ; First, reverse the stack alignment.
    add rsp, 8
    pop r13
    pop r12
    pop rbx

    leave
    ret

; Function: print_byte_bits -- Prints the 8 bits of a given byte using
;           the termbox2 API. Uses UTF-16 encoding (2 bytes per character).
; Args:
;   rdi: The value of the byte to print (set in the lower bits).
;   rsi: Row index
;   rdx: Col index
print_byte_bits:
    push rbp
    mov rbp, rsp

    sub rsp, 16  ; 16 byte buffer (local variable) + alignment
    
    ; Push 3 callee-saved registers. This also aligns the stack.    
    push rbx     
    push r12     
    push r13
    push r14

    ; Save the arguments
    mov r8, rdi        
    mov r12, rsi    ; r12 = Row index
    mov rax, 8
    mul rdx
    mov r13, rax    ; r13 = Col index * 8
    
    add r12, screen.START_Y
    add r13, screen.START_X

    lea rsi, [rbp - 16] ; rsi will be our pointer to the buffer on the stack
    
    mov rcx, 8         ; Loop 8 times for 8 bits
    xor rax, rax       ; Clear rax, as we will be copying only the lower byte.

.loop_conv_bit2byte:
    mov al, r8b        ; Copy the byte for bit extraction
    rol al, 1          ; Rotate the Most Significant Bit into the LSB position
    mov r8b, al        ; Store the rotated value back for the next iteration
    and al, 1          ; Isolate the bit (0 or 1)

    cmp al, 1
    je .set_bit_on_char   ;if 
.set_bit_off_char:        ;else
    mov rax, [uchar.bit_off]
    jmp .set_char_done
.set_bit_on_char:
    mov rax, [rand_idx_disp_arr]
    movzx eax, word [uchar.disp_arr + rax]
    jmp .set_char_done
.set_char_done:   
    mov [rsi], ax          ; Store the Unicode code point
    add rsi, 2             ; Move to the next position in the buffer
    dec rcx                ; Decrement bit counter; zf is updated
    jnz .loop_conv_bit2byte  

    ; Write the 8-byte buffer
    lea r14, [rbp - 16] 
    mov rbx, 8
.loop_tb_set_cell:
    ; Prepare tb_set_cell
    mov rdi, r13                    ; 1. rdi = x
    mov rsi, r12                    ; 2. rsi = y
    movzx edx, word [r14]           ; 3. rdx = Unicode code point
    mov rax, [rand_idx_color]
    mov ecx, dword [colors + rax] 
    mov rax, [rand_idx_fg_attr]
    or ecx, dword[fg_attr + rax]    ; 4. rcx = fg attr (color|attr)
    mov r8, 0                       ; 5. r8  = bg attr
    call tb_set_cell

    inc r13                         ; Increment x coord 
    add r14, 2                      ; Next UTF-16 character
    dec rbx                         ; Loop variant 
    jnz .loop_tb_set_cell

    ; Cleanup
    pop r14
    pop r13
    pop r12
    pop rbx
    leave    
    ret


; Function: get_rand_num -- Use the rdtsc instruction to generate a random
;           number for a given range (r) => [0 to (r-1)].
; Args:
;   rdi: range
get_rand_num:
    push rbp
    mov rbp, rsp

    ; rdtsc:
    ; Reads the current value of the processor's time-stamp counter (a 64-bit MSR) into the `edx:eax` registers. 
    ; The `edx` register is loaded with the high-order 32 bits of the MSR, and the `eax` register is loaded with the
    ; low-order 32 bits. (On processors that support the Intel 64 architecture, the high-order 32 bits of 
    ; each of `rax` and `rdx` are cleared.)
    rdtsc 

    ; We will discard the value in edx; the value in eax is sufficient for our random number.
    ; The dividend is implicitly the 128-bit value in `rdx:rax`.
    ; The quotient is stored in `rax`, and the remainder is in `rdx`.
    mov rdx, 0    ; Clear rdx for division
    div rdi       ; rax = rax / rdi, remainder in rdx
    mov rax, rdx  ; Set the remainder as the return value
    leave
    ret