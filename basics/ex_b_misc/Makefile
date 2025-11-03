# 
# Generate executable corresponding to each asm file
#
AS = nasm
LD = gcc
ASFLAGS = -g -f elf64
LDFLAGS = -g -m64

SRCS = $(wildcard *.asm)
OBJS = $(SRCS:.asm=.o)
EXES = $(SRCS:.asm=.bin) 

.PHONY: all clean

# -----------------------------------------------------
# Uncomment to keep the .o files 
.NOTINTERMEDIATE: $(OBJS)
# -----------------------------------------------------

# Default target: builds the program
all: $(EXES)
	@echo ""
	
# Rule to link the object file into an executable
%.bin: %.o
	$(LD) $(LDFLAGS) $< -o $@
	@echo -e "\e[1;32mExecutable: $(abspath $@) \e[0m"	

# Rule to assemble the source file into an object file
%.o: %.asm
	$(AS) $(ASFLAGS) $< -o $@

# Clean target: removes generated files
clean:
	rm -f $(OBJS) $(EXES)