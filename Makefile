# Author: *vvzhlw(fetch150zy)

.PHONY: all
all: monitor opensbi uboot

.PHONY: clean
clean: monitor-clean opensbi-clean uboot-clean
	
.PHONY: monitor
monitor:
	make -C monitor -j12

.PHONY: monitor-clean
monitor-clean:
	make -C monitor clean

.PHONY: opensbi
opensbi:
	ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- make -C opensbi PLATFORM=generic

.PHONY: opensbi-clean
opensbi-clean:
	make -C opensbi distclean

.PHONY: uboot
uboot:
	make -C uboot

.PHONY: uboot-clean
uboot-clean:
	make -C uboot clean
