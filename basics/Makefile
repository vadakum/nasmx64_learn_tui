#
# Build/Clean all examples
#

# Add new example directories 
define make_examples
	cd ex_a1_first	&& $(MAKE) $@ --no-print-directory
	cd ex_a2_hello	&& $(MAKE) $@ --no-print-directory
	cd ex_b_misc	&& $(MAKE) $@ --no-print-directory
	cd ex_c_pattern	&& $(MAKE) $@ --no-print-directory
endef

all:
	$(call make_examples, all)	
clean:
	$(call make_examples, clean)

