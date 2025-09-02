#define STACK_TOP     0x84000000
#define STACK_BOTTOM  0x83c00000
#define DRAM_BASE     0x80000000


#define SMM_BASE     0x80100000
#define SMM_SU_TH     0x80102000
#define SMM_M_TH     0x80101000

//alternative values
//#define LOCK_OSBI     0x1F00001F9B9D9B9D
//#define UNLOCK_OSBI     0x1F00001F9B9D9B9D
//#define UNLOCK_OSBI     0x1E00001E9B9D9B9D

#define LOCK_OSBI     	0x1F00181F18181B1D
#define UNLOCK_OSBI     0x1800181F1B1D1818

#define SMM_DATA     0x80140000

#define NUMBER_HARTS 5
#define SCRATCH_SIZE 8192

#define PAYLOAD_ADDR 0x80200000

#define FDT_ADDR	0x100c0
//#define FDT_RELOC_ADDR	0x82200000 0x81400000
#define FDT_RELOC_ADDR	0x81400000

#define OSBI_VEC 0x800404e8


#define DTB   0
#define INIT  8

#if __riscv_xlen == 64
# define STORE    sd
# define LOAD     ld
#else
# define STORE    sw
# define LOAD     lw
#endif

#include "mon_scratch.h"
#include <sbi/riscv_encoding.h>
#include <sbi/dorami_main.h>

#define RISCV_PTR		.dword

#define BOOT_STATUS_BOOT_HART_DONE	2

.macro	MOV_3R __d0, __s0, __d1, __s1, __d2, __s2
	add	\__d0, \__s0, zero
	add	\__d1, \__s1, zero
	add	\__d2, \__s2, zero
.endm

.macro	MOV_5R __d0, __s0, __d1, __s1, __d2, __s2, __d3, __s3, __d4, __s4
	add	\__d0, \__s0, zero
	add	\__d1, \__s1, zero
	add	\__d2, \__s2, zero
	add	\__d3, \__s3, zero
	add	\__d4, \__s4, zero
.endm

/*
 * If __start_reg <= __check_reg and __check_reg < __end_reg then
 *   jump to __pass
 */
.macro BRANGE __start_reg, __end_reg, __check_reg, __jump_lable
	blt	\__check_reg, \__start_reg, 999f
	bge	\__check_reg, \__end_reg, 999f
	j	\__jump_lable
999:
.endm

#define MON_CONSOLE 0x101000000000000
#define CON_ADDR 0x800838e8

.macro TMPPRINT __char
	li t5, CON_ADDR
	li t6, MON_CONSOLE
	ori t6, t6, \__char
	sd t6, (t5)
.endm



.section .reset, "ax", %progbits
.globl reset
.globl _start
reset:
#   li t0, OSBI_BASE
#   jr t0

# li t5, CON_ADDR
# li t6, MON_CONSOLE
# ori t6, t6, 0x4D
# sd t6, (t5)


_start:

  //Doing Reloc Lottery here, similar to OSBI, but for determining boot hart
  lla a6, _reloc_lottery
  li a7, 1
  amoadd.w a6, a7, (a6)
  bnez	a6, _wait_for_boot_hart
  //We are doing no relocation in our code...
  fence	rw, rw


  //Instead: Here now starts the init for the boot hart
  /* Reset all registers for non-boot HARTs */
	li	ra, 0
	call	_reset_regs

# /*-----------------------------*/
# 	/* Zero-out BSS */
	lla	s4, _bss_start
	lla	s5, _bss_end
_bss_zero:
	REG_S	zero, (s4)
	add	s4, s4, __SIZEOF_POINTER__
	blt	s4, s5, _bss_zero
# /*-----------------------------*/


/* Setup temporary trap handler */
	lla	s4, _start_hang
	csrw	CSR_MTVEC, s4

	/* Setup temporary stack */
	lla	s4, _scratch_area
	li	s5, (SCRATCH_SIZE * 2)
	add	sp, s4, s5

	/* We hardcode the number of harts and the Thread size here */
	li s7, NUMBER_HARTS //Number of HARTS on this hardware
	li s8, SCRATCH_SIZE //Stack Size per hart

	lla tp, _scratch_area//scratch space for all harts
	mul a5, s7, s8 
	add tp, tp, a5
	add	t3, tp, zero //copy of tp
	/* Counter */
	li t5, 0 //HART counter but backwards
	//addi t5, t5, -1
	li	t2, 1
	/* hartid 0 is mandated by ISA */
	li	t1, 0

_scratch_init:
	/*
	 * The following registers hold values that are computed before
	 * entering this block, and should remain unchanged.
	 *
	 * t3 -> the firmware end address
	 * s7 -> HART count
	 * s8 -> HART stack size
	 */
	add	tp, t3, zero
	mul	a5, s8, t1
	sub	tp, tp, a5
	li	a5, SCRATCH_SIZE
	sub	tp, tp, a5

	/* Initialize scratch space */
	/* Store fw_start and fw_size in scratch space */
	lla	a4, reset_vector
	sub	a5, t3, a4
	REG_S	a4, MON_SCRATCH_FW_START_OFFSET(tp)
	REG_S	a5, MON_SCRATCH_FW_SIZE_OFFSET(tp)
	/* Store warm_boot address in scratch space */
	lla	a4, _start_warm
	REG_S	a4, MON_SCRATCH_WARMBOOT_ADDR_OFFSET(tp)
	/* Store hartid-to-scratch function address in scratch space */
	lla	a4, _hartid_to_scratch
	REG_S	a4, MON_SCRATCH_HARTID_TO_SCRATCH_OFFSET(tp)
	/* Store OSBI Enter function address in scratch space */
	lla	a4, _mon_enter_osbi
	REG_S	a4, MON_SCRATCH_TRAP_EXIT_SECONDARY_OFFSET(tp)
	/* Store SU Enter function address in scratch space */
	lla	a4, _mon_enter_su
	REG_S	a4, MON_SCRATCH_TRAP_EXIT_SU_OFFSET(tp)
	/* Clear tmp0 in scratch space */
	REG_S	zero, SBI_SCRATCH_TMP0_OFFSET(tp)

	/* Store the arguments for next bootstage */
	REG_S	t5, MON_SCRATCH_ARG0_OFFSET(tp) //arg0 is the hartID
	REG_S	a1, MON_SCRATCH_ARG1_OFFSET(tp)
	REG_S	a2, MON_SCRATCH_ARG2_OFFSET(tp)

	addi t5, t5, 1

	lla a4, _scratch_addrs
	slli t4, t1, 3 //Check offset to which we want to save scratch address
	add a4, a4, t4
	sd tp, 0(a4)


	/* Move to next scratch space */
	add	t1, t1, t2
	blt	t1, s7, _scratch_init

	li a1, FDT_ADDR
	li t1, FDT_RELOC_ADDR

	j _fdt_reloc_done

_fdt_reloc_done:
	/* mark boot hart done */
	li	t0, BOOT_STATUS_BOOT_HART_DONE
	lla	t1, _boot_status
	REG_S	t0, 0(t1)
	fence	rw, rw
	j	_start_warm

_wait_for_boot_hart:
	li	t0, BOOT_STATUS_BOOT_HART_DONE
	lla	t1, _boot_status
	REG_L	t1, 0(t1)
	/* Reduce the bus traffic so that boot hart may proceed faster */
	nop
	nop
	nop
	bne	t0, t1, _wait_for_boot_hart

_start_warm:
	/* Reset all registers for non-boot HARTs */
	li	ra, 0
	call	_reset_regs

	/* Disable and clear all interrupts */
	csrw	CSR_MIE, zero
	csrw	CSR_MIP, zero

	/* Find HART count and HART stack size */
	//lla	a4, platform

	li	s7, NUMBER_HARTS
	li	s8, SCRATCH_SIZE

	//REG_L	s9, SBI_PLATFORM_HART_INDEX2ID_OFFSET(a4)

	/* Find HART id */
	csrr	s6, CSR_MHARTID

	/* Find HART index */
	beqz	s9, 3f
	li	a4, 0
1:
	lwu	a5, (s9)
	beq	a5, s6, 2f
	add	s9, s9, 4
	add	a4, a4, 1
	blt	a4, s7, 1b
	li	a4, -1
2:	add	s6, a4, zero
3:	bge	s6, s7, _start_hang

	/* Find the scratch space based on HART index */
	lla	tp, _scratch_area
	mul	a5, s7, s8
	add	tp, tp, a5
	mul	a5, s8, s6
	sub	tp, tp, a5
	li	a5, SCRATCH_SIZE
	sub	tp, tp, a5

	/* update the mscratch */
	csrw	CSR_MSCRATCH, tp

	/* Setup stack */
	add	sp, tp, zero

	/* Setup trap handler */
	//lla	a4, _trap_handler
	lla a4, _start_hang

	csrw	CSR_MTVEC, a4
	/* Initialize SBI runtime */
	csrr	a2, CSR_MSCRATCH
	call	mon_init

	/* We don't expect to reach here hence just hang */
	j	_start_hang




	.section .entry, "ax", %progbits
	.align 3
	.globl _reset_regs
_reset_regs:

	/* flush the instruction cache */
	fence.i
	/* Reset all registers except ra, a0, a1 and a2 */
	li sp, 0
	li gp, 0
	li tp, 0
	li t0, 0
	li t1, 0
	li t2, 0
	li s0, 0
	li s1, 0
	//li a3, 0
	li a4, 0
	li a5, 0
	li a6, 0
	li a7, 0
	li s2, 0
	li s3, 0
	li s4, 0
	li s5, 0
	li s6, 0
	li s7, 0
	li s8, 0
	li s9, 0
	li s10, 0
	li s11, 0
	li t3, 0
	li t4, 0
	li t5, 0
	li t6, 0
	csrw CSR_MSCRATCH, 0

	ret

	.section .entry, "ax", %progbits
	.align 3
	.globl _start_hang
_start_hang:
	wfi
	j	_start_hang


.section .entry, "ax", %progbits
	.align 3
	.globl _hartid_to_scratch
_hartid_to_scratch:
	/*
	 * a0 -> HART ID (passed by caller)
	 * a1 -> HART Index (passed by caller)
	 * t0 -> HART Stack Size
	 * t1 -> HART Stack End
	 * t2 -> Temporary
	 */
	//lla	t2, platform

	li t0, SCRATCH_SIZE
	li t2, NUMBER_HARTS

	sub	t2, t2, a1
	mul	t2, t2, t0
	lla	t1, _scratch_area
	add	t1, t1, t2
	li	t2, SCRATCH_SIZE
	sub	a0, t1, t2
	ret

/* Map implicit memset() added by compiler to sbi_memset() */
	.section .text
	.align 3
	.globl memset
memset:
	tail	sbi_memset


	.data
	.align 3
_reset_data:
_boot_status:
	RISCV_PTR	0
_reloc_lottery:
	RISCV_PTR	0

_scratch_addrs: //We hardcode space for 4 cores here to store scrach space addresses
	.dword 0
	.dword 0
	.dword 0
	.dword 0
	.dword 0

.macro	TRAP_SAVE_AND_SETUP_SP_T0
	/* Swap TP and MSCRATCH */
	csrrw	tp, CSR_MSCRATCH, tp

	/* Save T0 in scratch space */
	REG_S	t0, SBI_SCRATCH_TMP0_OFFSET(tp)

	/*
	 * Set T0 to appropriate exception stack
	 *
	 * Came_From_M_Mode = ((MSTATUS.MPP < PRV_M) ? 1 : 0) - 1;
	 * Exception_Stack = TP ^ (Came_From_M_Mode & (SP ^ TP))
	 *
	 * Came_From_M_Mode = 0    ==>    Exception_Stack = TP
	 * Came_From_M_Mode = -1   ==>    Exception_Stack = SP
	 */
	csrr	t0, CSR_MSTATUS
	srl	t0, t0, MSTATUS_MPP_SHIFT
	and	t0, t0, PRV_M
	slti	t0, t0, PRV_M
	add	t0, t0, -1
	xor	sp, sp, tp
	and	t0, t0, sp
	xor	sp, sp, tp
	xor	t0, tp, t0

	/* Save original SP on exception stack */
	REG_S	sp, (SBI_TRAP_REGS_OFFSET(sp) - SBI_TRAP_REGS_SIZE)(t0)

	/* Set SP to exception stack and make room for trap registers */
	add	sp, t0, -(SBI_TRAP_REGS_SIZE)

	/* Restore T0 from scratch space */
	REG_L	t0, SBI_SCRATCH_TMP0_OFFSET(tp)

	/* Save T0 on stack */
	REG_S	t0, SBI_TRAP_REGS_OFFSET(t0)(sp)

	/* Swap TP and MSCRATCH */
	csrrw	tp, CSR_MSCRATCH, tp
.endm

.macro	TRAP_SAVE_MEPC_MSTATUS have_mstatush
	/* Save MEPC and MSTATUS CSRs */
	csrr	t0, CSR_MEPC
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mepc)(sp)
	csrr	t0, CSR_MSTATUS
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mstatus)(sp)
	.if \have_mstatush
	csrr	t0, CSR_MSTATUSH
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mstatusH)(sp)
	.else
	REG_S	zero, SBI_TRAP_REGS_OFFSET(mstatusH)(sp)
	.endif
.endm

.macro	TRAP_SAVE_MEPC_MSTATUS_SSCRATCH have_mstatush
	/* Save MEPC and MSTATUS CSRs */
	csrr	t0, CSR_MEPC
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mepc)(sp)
	csrr	t0, CSR_SSCRATCH
	REG_S	t0, SBI_TRAP_REGS_OFFSET(sscratch)(sp)
	csrr	t0, CSR_MSTATUS
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mstatus)(sp)
	.if \have_mstatush
	csrr	t0, CSR_MSTATUSH
	REG_S	t0, SBI_TRAP_REGS_OFFSET(mstatusH)(sp)
	.else
	REG_S	zero, SBI_TRAP_REGS_OFFSET(mstatusH)(sp)
	.endif
.endm

.macro	TRAP_SAVE_GENERAL_REGS_EXCEPT_SP_T0
	/* Save all general regisers except SP and T0 */
	REG_S	zero, SBI_TRAP_REGS_OFFSET(zero)(sp)
	REG_S	ra, SBI_TRAP_REGS_OFFSET(ra)(sp)
	REG_S	gp, SBI_TRAP_REGS_OFFSET(gp)(sp)
	REG_S	tp, SBI_TRAP_REGS_OFFSET(tp)(sp)
	REG_S	t1, SBI_TRAP_REGS_OFFSET(t1)(sp)
	REG_S	t2, SBI_TRAP_REGS_OFFSET(t2)(sp)
	REG_S	s0, SBI_TRAP_REGS_OFFSET(s0)(sp)
	REG_S	s1, SBI_TRAP_REGS_OFFSET(s1)(sp)
	REG_S	a0, SBI_TRAP_REGS_OFFSET(a0)(sp)
	REG_S	a1, SBI_TRAP_REGS_OFFSET(a1)(sp)
	REG_S	a2, SBI_TRAP_REGS_OFFSET(a2)(sp)
	REG_S	a3, SBI_TRAP_REGS_OFFSET(a3)(sp)
	REG_S	a4, SBI_TRAP_REGS_OFFSET(a4)(sp)
	REG_S	a5, SBI_TRAP_REGS_OFFSET(a5)(sp)
	REG_S	a6, SBI_TRAP_REGS_OFFSET(a6)(sp)
	REG_S	a7, SBI_TRAP_REGS_OFFSET(a7)(sp)
	REG_S	s2, SBI_TRAP_REGS_OFFSET(s2)(sp)
	REG_S	s3, SBI_TRAP_REGS_OFFSET(s3)(sp)
	REG_S	s4, SBI_TRAP_REGS_OFFSET(s4)(sp)
	REG_S	s5, SBI_TRAP_REGS_OFFSET(s5)(sp)
	REG_S	s6, SBI_TRAP_REGS_OFFSET(s6)(sp)
	REG_S	s7, SBI_TRAP_REGS_OFFSET(s7)(sp)
	REG_S	s8, SBI_TRAP_REGS_OFFSET(s8)(sp)
	REG_S	s9, SBI_TRAP_REGS_OFFSET(s9)(sp)
	REG_S	s10, SBI_TRAP_REGS_OFFSET(s10)(sp)
	REG_S	s11, SBI_TRAP_REGS_OFFSET(s11)(sp)
	REG_S	t3, SBI_TRAP_REGS_OFFSET(t3)(sp)
	REG_S	t4, SBI_TRAP_REGS_OFFSET(t4)(sp)
	REG_S	t5, SBI_TRAP_REGS_OFFSET(t5)(sp)
	REG_S	t6, SBI_TRAP_REGS_OFFSET(t6)(sp)
.endm

.macro	TRAP_CALL_C_ROUTINE_OSBI_ENTER
	/* Call C routine */
	add	a0, sp, zero
	call	mon_trap_return_osbi
.endm

.macro	TRAP_CALL_C_ROUTINE_SU_ENTER
	/* Call C routine */
	add	a0, sp, zero
	call	mon_trap_handler_sumode
.endm

.macro	TRAP_RESTORE_GENERAL_REGS_EXCEPT_A0_T0
	/* Restore all general regisers except A0 and T0 */
//	REG_L	t6, SBI_TRAP_REGS_OFFSET(t6)(a0)
//	csrrw	t6, mtvec, t6
//	li		t6, SMM_M_TH

	REG_L	ra, SBI_TRAP_REGS_OFFSET(ra)(a0)
	REG_L	sp, SBI_TRAP_REGS_OFFSET(sp)(a0)
	REG_L	gp, SBI_TRAP_REGS_OFFSET(gp)(a0)
	REG_L	tp, SBI_TRAP_REGS_OFFSET(tp)(a0)
	REG_L	t1, SBI_TRAP_REGS_OFFSET(t1)(a0)
	REG_L	t2, SBI_TRAP_REGS_OFFSET(t2)(a0)
	REG_L	s0, SBI_TRAP_REGS_OFFSET(s0)(a0)
	REG_L	s1, SBI_TRAP_REGS_OFFSET(s1)(a0)
	REG_L	a1, SBI_TRAP_REGS_OFFSET(a1)(a0)
	REG_L	a2, SBI_TRAP_REGS_OFFSET(a2)(a0)
	REG_L	a3, SBI_TRAP_REGS_OFFSET(a3)(a0)
	REG_L	a4, SBI_TRAP_REGS_OFFSET(a4)(a0)
	REG_L	a5, SBI_TRAP_REGS_OFFSET(a5)(a0)
	REG_L	a6, SBI_TRAP_REGS_OFFSET(a6)(a0)
	REG_L	a7, SBI_TRAP_REGS_OFFSET(a7)(a0)
	REG_L	s2, SBI_TRAP_REGS_OFFSET(s2)(a0)
	REG_L	s3, SBI_TRAP_REGS_OFFSET(s3)(a0)
	REG_L	s4, SBI_TRAP_REGS_OFFSET(s4)(a0)
	REG_L	s5, SBI_TRAP_REGS_OFFSET(s5)(a0)
	REG_L	s6, SBI_TRAP_REGS_OFFSET(s6)(a0)
	REG_L	s7, SBI_TRAP_REGS_OFFSET(s7)(a0)
	REG_L	s8, SBI_TRAP_REGS_OFFSET(s8)(a0)
	REG_L	s9, SBI_TRAP_REGS_OFFSET(s9)(a0)
	REG_L	s10, SBI_TRAP_REGS_OFFSET(s10)(a0)
	REG_L	s11, SBI_TRAP_REGS_OFFSET(s11)(a0)
	REG_L	t3, SBI_TRAP_REGS_OFFSET(t3)(a0)
	REG_L	t4, SBI_TRAP_REGS_OFFSET(t4)(a0)
	REG_L	t5, SBI_TRAP_REGS_OFFSET(t5)(a0)
	REG_L	t6, SBI_TRAP_REGS_OFFSET(t6)(a0)//
.endm

.macro	TRAP_RESTORE_MEPC_MSTATUS have_mstatush
	/* Restore MEPC and MSTATUS CSRs */
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mepc)(a0)
	csrw	CSR_MEPC, t0
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mstatus)(a0)
	csrw	CSR_MSTATUS, t0
	.if \have_mstatush
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mstatusH)(a0)
	csrw	CSR_MSTATUSH, t0
	.endif
.endm

.macro	TRAP_RESTORE_MEPC_MSTATUS_SSCRATCH have_mstatush
	/* Restore MEPC and MSTATUS CSRs */
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mepc)(a0)
	csrw	CSR_MEPC, t0
	REG_L	t0, SBI_TRAP_REGS_OFFSET(sscratch)(a0)
	csrw	CSR_SSCRATCH, t0
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mstatus)(a0)
	csrw	CSR_MSTATUS, t0
	.if \have_mstatush
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mstatusH)(a0)
	csrw	CSR_MSTATUSH, t0
	.endif
.endm

.macro TRAP_RESTORE_A0_T0
	/* Restore T0 */
	REG_L	t0, SBI_TRAP_REGS_OFFSET(t0)(a0)

	/* Restore A0 */
	REG_L	a0, SBI_TRAP_REGS_OFFSET(a0)(a0)
.endm

# .macro TRAP_OSBI_RESTORE_MSCRATCH
# 	REG_L	t0, SBI_TRAP_REGS_OFFSET(mscratch)(a0)
# 	csrw	CSR_MSCRATCH, t0
# .endm

.macro TRAP_OSBI_RESTORE_MSCRATCH_STAGE1
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mscratch)(a0)
	csrw	sscratch, t0
.endm

.macro TRAP_OSBI_RESTORE_MSCRATCH_STAGE2
	REG_L	t0, SBI_TRAP_REGS_OFFSET(mscratch)(a0)
	csrw	CSR_MSCRATCH, t0
	# csrrw t6, pmpaddr12, t6
	# csrw CSR_MSCRATCH, t6
	# csrr t6, pmpaddr12
.endm

.macro TRAP_OSBI_GET_MSCRATCH
//Getting new scratch space addresses

  csrrw t6, mscratch, t6 //store t6 temporarily

  csrr t6, mhartid //get hartid
  //addi t6, 0 //subtract target value
  bnez t6, 1f //If not equal to zero (wrong value), jump to next one
  lla t6, _scratch_addrs //otherwise put address of scratch array into t6
  //c.addi t6, 8 //Manually add immediate to the value
  j 5f //Jump to finisher 

1:
  csrr t6, mhartid 
  c.addi t6, -1
  bnez t6, 2f
  lla t6, _scratch_addrs
  c.addi t6, 8
  j 5f

2:
  csrr t6, mhartid
  c.addi t6, -2
  bnez t6, 3f
  lla t6, _scratch_addrs
  c.addi t6, 16
  j 5f

3:
  csrr t6, mhartid
  c.addi t6, -3
  bnez t6, 4f
  lla t6, _scratch_addrs
  c.addi t6, 24
  j 5f

4:
  csrr t6, mhartid
  c.addi t6, -4
  bnez t6, 4b //Here we jump backwards and loop indefinitely (unknown core id)
  lla t6, _scratch_addrs
  c.addi t6, 31
  c.addi t6, 1

5:
  REG_L t6, 0(t6)
  csrrw t6, mscratch, t6 //restore scratch register and switch back temp value
.endm

.macro TRAP_OSBI_SAVE_ADDITIONAL
	csrrw	tp, CSR_MSCRATCH, tp

	/* Save T0 in scratch space */
	REG_S	t0, SBI_SCRATCH_TMP0_OFFSET(tp)
	//Read pmpcfg0 and also store in scratch space
	csrrw t0, pmpcfg0
	REG_S	t0, MON_SCRATCH_PMPCONFIG_OFFSET(tp)
	//Restore register state
	REG_L	t0, SBI_SCRATCH_TMP0_OFFSET(tp)
	csrrw	tp, CSR_MSCRATCH, tp
.endm

.macro TRAP_OSBI_PUSH_PMP_MSCRATCH
	csrrw t0, sscratch, t0
	li t0, LOCK_OSBI
	csrrw t0, pmpcfg0, t0
	csrr t0, CSR_MSCRATCH
	csrrw t0, sscratch, t0
.endm

.macro TRAP_OSBI_PULL_PMP_MSCRATCH //Assumes a0 has register struct address
	csrrw	tp, CSR_MSCRATCH, tp
	REG_S	t0, SBI_SCRATCH_TMP0_OFFSET(tp)
	csrr t0, sscratch
	REG_S t0, SBI_TRAP_REGS_OFFSET(mscratch)(sp)
	REG_L	t0, SBI_SCRATCH_TMP0_OFFSET(tp)
	csrrw	tp, CSR_MSCRATCH, tp
.endm

.macro TRAP_SU_SET_MTVEC
	lla t0, _mon_enter_su
	csrrw t0, mtvec, t0
.endm

.macro TRAP_OSBI_SET_MTVEC
	li t0, OSBI_VEC
	csrrw t0, mtvec, t0
.endm

.macro TRAP_OSBI_SET_PMP //(_launch_firmware)
	csrrw t0, sscratch, t0
	li t0, UNLOCK_OSBI
	csrw pmpcfg0, t0 //(goes to _firmware_start)
	//here starts first instruction of OSBI, "sliding" into it with PC advancing
	//csrrw t0, sscratch, t0
.endm

.section ._mon_enter_osbi, "ax", %progbits
.globl _mon_enter_osbi
_mon_enter_osbi: //(_P_entry_from_F)
	csrrw t6, sscratch, t6 //"Part of ABI", used sscratch for saving register and jumping
  TRAP_OSBI_PUSH_PMP_MSCRATCH
  TRAP_OSBI_GET_MSCRATCH
  TRAP_SAVE_AND_SETUP_SP_T0
  TRAP_SAVE_MEPC_MSTATUS 0
  TRAP_SAVE_GENERAL_REGS_EXCEPT_SP_T0
  TRAP_OSBI_PULL_PMP_MSCRATCH
  lla t6, _start_hang
  csrrw t6, mtvec, t6
  TRAP_CALL_C_ROUTINE_OSBI_ENTER


.section ._mon_exit_to_su, "ax", %progbits
.globl _mon_exit_to_su
_mon_exit_to_su:
  TRAP_SU_SET_MTVEC
  TRAP_RESTORE_GENERAL_REGS_EXCEPT_A0_T0
  TRAP_RESTORE_MEPC_MSTATUS_SSCRATCH 0
  TRAP_RESTORE_A0_T0
  mret

.section ._mon_enter_su, "ax", %progbits
.globl _mon_enter_su
_mon_enter_su:
	TRAP_SAVE_AND_SETUP_SP_T0

	TRAP_SAVE_MEPC_MSTATUS_SSCRATCH 0

	TRAP_SAVE_GENERAL_REGS_EXCEPT_SP_T0

	TRAP_CALL_C_ROUTINE_SU_ENTER

.section ._mon_exit_to_osbi, "ax", %progbits
.globl _mon_exit_to_osbi
_mon_exit_to_osbi:
  //TRAP_OSBI_RESTORE_MSCRATCH_STAGE1
  TRAP_OSBI_SET_MTVEC
  TRAP_RESTORE_GENERAL_REGS_EXCEPT_A0_T0
  TRAP_RESTORE_MEPC_MSTATUS 0
  TRAP_OSBI_RESTORE_MSCRATCH_STAGE2
  TRAP_RESTORE_A0_T0
  j _mon_goto_secondary_lastbits

.section ._mon_jmp_osbi, "ax", %progbits
.globl _mon_jmp_osbi
_mon_jmp_osbi:
  j .-0x7F000
  //j .-0xFF000


.section .scratch_area, "ax", %progbits
.globl _scratch_area
_scratch_area:
RISCV_PTR	0

.section .sanctum_area, "ax", %progbits
.globl _sanctum_area
_sanctum_area:
RISCV_PTR	0

.section ._mon_goto_secondary, "ax", %progbits
.globl _mon_goto_secondary //nop padding (2033) to get to end of page
.rept 2033 //shorter form
	nop
.endr
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop
# nop

_mon_goto_secondary_lastbits:
TRAP_OSBI_SET_PMP