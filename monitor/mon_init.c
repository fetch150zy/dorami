#include "mon_scratch.h"
#include "sbi/sbi_types.h"
#include "sbi/riscv_atomic.h"
#include "sbi/riscv_io.h"


#include "sbi/sifive-uart.h"
#include "sbi/sbi_console.h"

#include "sm/sm.h"


#define BANNER                                   \
"              _                _____ __  ___\n" \
"   ____ ___  (_)_____________ / ___//  |/  /\n" \
"  / __ `__ \\/ / ___/ ___/ __ \\\\__ \\/ /|_/ / \n" \
" / / / / / / / /__/ /  / /_/ /__/ / /  / /  \n" \
"/_/ /_/ /_/_/\\___/_/   \\____/____/_/  /_/   \n" 

static volatile atomic_t coldboot_lottery = ATOMIC_INITIALIZER(0);
static volatile unsigned int waiter = 0;

static void __noreturn init_coldboot(struct mon_scratch *scratch, u32 hartid, unsigned long inputA, unsigned long inputB){
    (void) scratch;
    (void) hartid;

	sifive_uart_init(0x10010000, 0x00, 0x1c200);
    sbi_printf(BANNER);

	sm_init(1);

	waiter = 1;
	(void) waiter;
	register unsigned long a0 asm("a0") = scratch->arg0;
	register unsigned long a1 asm("a1") = scratch->arg1;
	register unsigned long a2 asm("a2") = scratch->arg2;

	asm("csrw mscratch, zero; li t6, 0x1F00001B1B1D181D; csrrw t6, pmpcfg0, t6; li t6, 0x80040000; c.jr t6" : : "r"(a0), "r"(a1), "r"(a2));

    __builtin_unreachable();
}

static void __noreturn init_warmboot(struct mon_scratch *scratch, u32 hartid){
    (void) scratch;
    (void) hartid;

	sm_init(0);

	for (size_t i = 0; i < 0x10000; i++)
	{
		asm("nop");
	}

	register unsigned long a0 asm("a0") = scratch->arg0;
	register unsigned long a1 asm("a1") = scratch->arg1;
	register unsigned long a2 asm("a2") = scratch->arg2; 

	asm("csrw mscratch, zero; li t6, 0x1F00001B1B1D181D; csrrw t6, pmpcfg0, t6; li t6, 0x80040000; c.jr t6" : : "r"(a0), "r"(a1), "r"(a2));

    __builtin_unreachable();
}


void __noreturn mon_init(unsigned long inputA, unsigned long inputB, struct mon_scratch *scratch)
{
	bool coldboot			= FALSE;
	u32 hartid			= current_hartid();

	if (atomic_xchg(&coldboot_lottery, 1) == 0)
		coldboot = TRUE;

	if (coldboot)
		init_coldboot(scratch, hartid, inputA, inputB);
	else
		init_warmboot(scratch, hartid);
}