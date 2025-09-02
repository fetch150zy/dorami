#include "sbi/riscv_asm.h"

/** Offset of fw_start member in mon_scratch */
#define MON_SCRATCH_FW_START_OFFSET		(0 * __SIZEOF_POINTER__)
/** Offset of fw_size member in mon_scratch */
#define MON_SCRATCH_FW_SIZE_OFFSET		(1 * __SIZEOF_POINTER__)
/** Offset of warmboot_addr member in mon_scratch */
#define MON_SCRATCH_WARMBOOT_ADDR_OFFSET	(2 * __SIZEOF_POINTER__)
/** Offset of hartid_to_scratch member in mon_scratch */
#define MON_SCRATCH_HARTID_TO_SCRATCH_OFFSET	(3 * __SIZEOF_POINTER__)
/** Offset of trap_exit_secondary in mon_scratch */
#define MON_SCRATCH_TRAP_EXIT_SECONDARY_OFFSET	    (4 * __SIZEOF_POINTER__)
/** Offset of trap_exit_su in mon_scratch */
#define MON_SCRATCH_TRAP_EXIT_SU_OFFSET		(5 * __SIZEOF_POINTER__)
/** Offset of tmp0 member in sbi_scratch */
#define SBI_SCRATCH_TMP0_OFFSET			(6 * __SIZEOF_POINTER__)
/** Offset of pmpconfig-copy in mon_scratch */
#define MON_SCRATCH_PMPCONFIG_OFFSET	    (7 * __SIZEOF_POINTER__)
/** Offset of trap_exit_su in mon_scratch */
#define MON_SCRATCH_ARG0_OFFSET		(8 * __SIZEOF_POINTER__)
/** Offset of argument0 in mon_scratch */
#define MON_SCRATCH_ARG1_OFFSET		(9 * __SIZEOF_POINTER__)
/** Offset of argument1 in mon_scratch */
#define MON_SCRATCH_ARG2_OFFSET		(10 * __SIZEOF_POINTER__)
/** Offset of argument2 in mon_scratch */
#define MON_SCRATCH_CTENTER_OFFSET		(11 * __SIZEOF_POINTER__)
/** Offset of cycle-counter when entering M-mode in mon_scratch */
#define MON_SCRATCH_TMENTER_OFFSET		(12 * __SIZEOF_POINTER__)
/** Offset of cycle-counter when entering M-mode in mon_scratch */
#define MON_SCRATCH_LASTMODE_OFFSET		(13 * __SIZEOF_POINTER__)


#ifndef __ASSEMBLER__

struct mon_scratch {
    /** Start (or base) address of firmware linked to OpenSBI library */
	unsigned long fw_start;
	/** Size (in bytes) of firmware linked to OpenSBI library */
	unsigned long fw_size;
    /** Warm boot entry point address for this HART */
	unsigned long warmboot_addr;
    /** Address of HART ID to sbi_scratch conversion function */
	unsigned long hartid_to_scratch;
    /** Address of trap exit function to secondary*/
	unsigned long trap_exit_secondary;
    /** Address of trap exit function to SU*/
	unsigned long trap_exit_su;
    /** Temporary storage */
	unsigned long tmp0;
	/** CSR_VAL of PMPconfig0*/
	unsigned long pmpconfig;
	/** CSR_VAL of PMPconfig0*/
	unsigned long arg0;
	/** CSR_VAL of PMPconfig0*/
	unsigned long arg1;
	/** CSR_VAL of PMPconfig0*/
	unsigned long arg2;
	/** Cycle counter at beginning of enering M-Mode */
	unsigned long cycle_enter;
	/** Cycle counter at beginning of enering M-Mode */
	unsigned long timer_enter;
	/** LAST_Mode to verify if we are entering though corret trap handler*/
	unsigned long last_mode;
};

#endif
