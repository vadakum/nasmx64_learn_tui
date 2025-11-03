# 
# Generate executable corresponding to each asm file
#
AS = nasm
ASFLAGS = -g -f elf64

CC = gcc
CCFLAGS = -c

LD = gcc
LDFLAGS = -g -m64 -L ./termbox2 -l termbox2

ASM_TARGETS = mobi_whale.bin mseg_display_term.bin mseg_display.bin
C_TARGETS	= try_extern_termbox.bin

.PHONY: all clean

# -----------------------------------------------------
# Uncomment to keep the .o files 
#.NOTINTERMEDIATE: $(OBJS)
# -----------------------------------------------------

# Default target: builds the program
all: build_termbox2 $(ASM_TARGETS) $(C_TARGETS)
	@echo ""
	
build_termbox2:
	@echo "Building termbox2"
	$(MAKE) --quiet -C ./termbox2
	@echo

# Rule to link the object file into an executable
%.bin: %.o
	$(LD) $< -o $@ $(LDFLAGS)
	@echo -e "\e[1;32mExecutable: $(abspath $@) \e[0m"	

# Rule to assemble the asm source file into an object file
%.o: %.asm
	$(AS) $(ASFLAGS) $< -o $@

# Rule to assemble the c source file into an object file
%.o: %.c
	$(CC) $(CCFLAGS) $< -o $@

# Clean target: removes generated files
clean:
	rm -f $(ASM_TARGETS) $(C_TARGETS) *.o
