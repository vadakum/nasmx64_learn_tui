PROG1	= first_gcc
PROG2	= first_ld

# Define the assembler and linker
AS1 = nasm
AS2 = nasm

LD1 = gcc
LD2 = ld

# Assembler and Linker Flags
AS1FLAGS = -g -f elf64
AS2FLAGS = -g -f elf64

LD1FLAGS =  -g -m64 
LD2FLAGS =  -g -m64

# Target, source, and object files
TARGET1  = $(PROG1).bin
SRC1     = $(PROG1).asm
OBJ1     = $(SRC1:.asm=.o)

TARGET2  = $(PROG2).bin
SRC2     = $(PROG2).asm
OBJ2     = $(SRC2:.asm=.o)

# Phony targets to prevent conflicts with file names
.PHONY: all clean

# Default target: builds the program
all: $(TARGET1) $(TARGET2)
	@echo ""

# Rule to link the object file into an executable
$(TARGET1): $(OBJ1)
	$(LD1) $(LD1FLAGS) $< -o $@
	@echo -e "\e[1;32mExecutable: $(abspath $@) \e[0m"	

$(TARGET2): $(OBJ2)
	$(LD2) $(LDF2LAGS) $< -o $@
	@echo -e "\e[1;32mExecutable: $(abspath $@) \e[0m"	

# Rule to assemble the source file into an object file
$(OBJ1): $(SRC1)
	$(AS1) $(AS1FLAGS) $< -o $@

$(OBJ2): $(SRC2)
	$(AS2) $(AS2FLAGS) $< -o $@

# Clean target: removes generated files
clean:
	rm -f $(OBJ1) $(TARGET1) $(OBJ2) $(TARGET2)
