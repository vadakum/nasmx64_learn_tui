PROG	= hello

# Define the assembler and linker
AS = nasm
LD = gcc
# Assembler and Linker Flags
ASFLAGS = -g -f elf64
LDFLAGS = -g -m64 

# Target, source, and object files
TARGET  = $(PROG).bin
SRC     = $(PROG).asm
OBJ     = $(SRC:.asm=.o)

# Default target: builds the program
all: $(TARGET)
	@echo ""
	
# Rule to link the object file into an executable
$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) $< -o $@
	@echo -e "\e[1;32mExecutable: $(abspath $@) \e[0m"	

# Rule to assemble the source file into an object file
$(OBJ): $(SRC)
	$(AS) $(ASFLAGS) $< -o $@

# Clean target: removes generated files
clean:
	rm -f $(OBJ) $(TARGET)