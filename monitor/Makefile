march ?= rv64imafdc
mabi ?= lp64
CC = riscv64-unknown-elf-gcc
OBJCOPY ?= riscv64-unknown-elf-objcopy

CFLAGS = \
	-g -march=$(march) -mcmodel=medany -mabi=$(mabi) \
	-nostdlib -nostartfiles -fno-common -std=gnu11 \
	-fno-builtin \
	-static -zexecstack \
	-O2 -Wall
O ?=.

ASFLAGS		=	-g -Wall -nostdlib
ASFLAGS		+=	-fno-omit-frame-pointer -fno-optimize-sibling-calls -mstrict-align

# ^ consider taking out -g -Og and putting in -O2

monitors=\
	$(O)/monitor.elf \
	$(O)/monitor.bin

.PHONY: all
all: $(monitors)

.PHONY: clean
clean:
	rm -f $(monitors)

monitor_sources = \
	./monitor.S \
	./monitor.c \
	./mon_init.c \
	./mon_utils.c \
	./sbi/riscv_atomic.c \
	./sbi/sbi_bitops.c \
	./sbi/riscv_locks.c \
	./sbi/sbi_console.c \
	./sbi/sbi_string.c \
	./sbi/sifive-uart.c \
	./sm/sm-sbi-opensbi.c \
	./sbi/dorami_main.c \
	./sm/sm.c \
	./sm/pmp.c \
	./sm/ed25519/fe.c \
	./sm/ed25519/ge.c \
	./sm/ed25519/keypair.c \
	./sm/ed25519/sc.c \
	./sm/ed25519/sign.c \
	./sm/hkdf_sha3_512/hkdf_sha3_512.c \
	./sm/hmac_sha3/hmac_sha3.c \
	./sm/sha3/sha3.c \
	./sm/crypto.c \
	./sm/platform/generic/platform.c \
	./sm/enclave.c \
	./sm/mprv.S \
	./sm/thread.c \
	./sm/attest.c \
	./sm/cpu.c \
	./sm/sm-sbi.c \
	./sm/plugins/multimem.c \
	./sm/plugins/plugins.c \
	./sm/ipi.c

%.elf: $(monitor_sources) monitor.ld
	$(CC) $(CFLAGS) -I./ -L . -T monitor.ld -g -o $@ $(monitor_sources)

%.bin: %.elf
	$(OBJCOPY) -O binary  $< $@;

