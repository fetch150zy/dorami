/**
 * Main Logic of Dorami monitor that performs switching between compartments and S/U-mode
 */



#include <sbi/riscv_asm.h>
#include <sbi/riscv_encoding.h>
#include <sbi/sbi_console.h>
#include <sbi/dorami_main.h>
#include <sbi/riscv_io.h>

#include <sbi/sbi_string.h>
#include <sbi/sbi_types.h>
#include <sbi/sbi_ecall_interface.h>
#include <sm/sm-sbi-opensbi.h>
#include <sm/enclave.h>

#include <sm/ipi.h>

#include <mon_utils.h>
#include <mon_scratch.h>


static void __noreturn sbi_trap_error(const char *msg, int rc,
				      ulong mcause, ulong mtval, ulong mtval2,
				      ulong mtinst, struct sbi_trap_regs *regs)
{
	sbi_hart_hang();
}

static void sbi_print_regs(const char *msg, int rc,
				      ulong mcause, ulong mtval, ulong mtval2,
				      ulong mtinst, struct sbi_trap_regs *regs)
{
	u32 hartid = current_hartid();

	sbi_printf("%s: hart%d: %s (error %d)\n", __func__, hartid, msg, rc);
	sbi_printf("%s: hart%d: mcause=0x%" PRILX " mtval=0x%" PRILX "\n",
		   __func__, hartid, mcause, mtval);
	sbi_printf("%s: hart%d: mepc=0x%" PRILX " mstatus=0x%" PRILX "\n",
		   __func__, hartid, regs->mepc, regs->mstatus);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "ra", regs->ra, "sp", regs->sp);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "gp", regs->gp, "tp", regs->tp);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "s0", regs->s0, "s1", regs->s1);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "a0", regs->a0, "a1", regs->a1);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "a2", regs->a2, "a3", regs->a3);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "a4", regs->a4, "a5", regs->a5);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "a6", regs->a6, "a7", regs->a7);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "s2", regs->s2, "s3", regs->s3);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "s4", regs->s4, "s5", regs->s5);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "s6", regs->s6, "s7", regs->s7);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "s8", regs->s8, "s9", regs->s9);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "s10", regs->s10, "s11", regs->s11);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "t0", regs->t0, "t1", regs->t1);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "t2", regs->t2, "t3", regs->t3);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "t4", regs->t4, "t5", regs->t5);
	sbi_printf("%s: hart%d: %s=0x%" PRILX "\n", __func__, hartid, "t6",
		   regs->t6);
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "stvec", csr_read(CSR_STVEC), "sstatus", csr_read(CSR_SSTATUS));
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "sscratch", csr_read(CSR_SSCRATCH), "scause", csr_read(CSR_SCAUSE));
	sbi_printf("%s: hart%d: %s=0x%" PRILX " %s=0x%" PRILX "\n", __func__,
		   hartid, "stval", csr_read(CSR_STVAL), "sepc", csr_read(CSR_SEPC));

}

int sbi_trap_redirect(struct sbi_trap_regs *regs,
		      struct sbi_trap_info *trap)
{
	return 0;
}

//4 cores, and reach has one slot for temporarily storing a context
static volatile struct sbi_trap_regs temporary_registers[5] = {0};
static volatile struct sbi_trap_info temporary_infos[5] = {0};

#define memset		sbi_memset


unsigned int mon_ecall_enter(struct sbi_trap_regs *regs, unsigned long hartid){
	unsigned long extension_id = regs->a7;
	unsigned long func_id = regs->a6;

	struct sbi_trap_regs temp = {0};
	//sbi_printf("Ecall! Extension: %lx Function: %lx!\n", extension_id, func_id);

	sbi_memcpy(&temporary_registers[hartid], regs, sizeof(struct sbi_trap_regs));

	*regs = temp;
	regs->mepc = temporary_registers[hartid].mepc;
	regs->mstatus = temporary_registers[hartid].mstatus;
	regs->mscratch = temporary_registers[hartid].mscratch;

	if(extension_id == SBI_EXT_BASE){
		regs->a7 = temporary_registers[hartid].a7;
		regs->a6 = temporary_registers[hartid].a6;
		if(func_id == SBI_EXT_BASE_PROBE_EXT){
			regs->a0 = temporary_registers[hartid].a0;
		}
		return 2;
	} else if (extension_id >= 0x00 && extension_id <= 0x0F){
		regs->a7 = temporary_registers[hartid].a7;
		if(func_id )
		regs->a0 = temporary_registers[hartid].a0;
		switch (func_id)
		{
		case 0:
		case 1:
		case 4:
		case 5:
			regs->a0 = temporary_registers[hartid].a0;
			break;
		case 6:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			break;
		case 7:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			regs->a3 = temporary_registers[hartid].a3;
			break;
		default:
			break;
		}
	} else if(extension_id == SBI_EXT_TIME){
		regs->a7 = temporary_registers[hartid].a7;
		regs->a0 = temporary_registers[hartid].a0;
	} else if(extension_id == SBI_EXT_IPI){
		regs->a7 = temporary_registers[hartid].a7;
		regs->a0 = temporary_registers[hartid].a0;
		regs->a1 = temporary_registers[hartid].a1;
	} else if(extension_id == SBI_EXT_RFENCE){
		regs->a7 = temporary_registers[hartid].a7;
		regs->a6 = temporary_registers[hartid].a6;
		
		switch (func_id)
		{
		case 0:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			break;
		case 1:
		case 4:
		case 6:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			regs->a3 = temporary_registers[hartid].a3;
			break;
		case 2:
		case 3:
		case 5:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			regs->a3 = temporary_registers[hartid].a3;
			regs->a4 = temporary_registers[hartid].a4;
			break;
		default:
			break;
		}
	} else if(extension_id == SBI_EXT_HSM){
		regs->a7 = temporary_registers[hartid].a7;
		regs->a6 = temporary_registers[hartid].a6;
		
		switch (func_id)
		{
		case 0:
		case 3:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			break;
		case 2:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			break;
		default:
			break;
		}
	} else if(extension_id == SBI_EXT_SRST){
		regs->a7 = temporary_registers[hartid].a7;
		regs->a6 = temporary_registers[hartid].a6;
		regs->a0 = temporary_registers[hartid].a0;
		regs->a1 = temporary_registers[hartid].a1;
	} else if(extension_id == SBI_EXT_PMU){
		regs->a7 = temporary_registers[hartid].a7;
		regs->a6 = temporary_registers[hartid].a6;

		switch (func_id)
		{
		case 1:
		case 5:
			regs->a0 = temporary_registers[hartid].a0;
			break;
		case 2:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			regs->a3 = temporary_registers[hartid].a3;
			regs->a4 = temporary_registers[hartid].a4;
			break;
		case 3:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			regs->a3 = temporary_registers[hartid].a3;
			break;
		case 4:
			regs->a0 = temporary_registers[hartid].a0;
			regs->a1 = temporary_registers[hartid].a1;
			regs->a2 = temporary_registers[hartid].a2;
			break;
		default:
			break;
		}
	}

	return 0;
}

volatile unsigned int mon_enclave_execution[5] = {0};
volatile unsigned long OSBI_mscratch[5] = {0};
static volatile unsigned long sscratch_double_save[5] = {0};
static volatile unsigned long sscratch_double_save_enclave[5] = {0};


struct sbi_trap_regs *mon_trap_handler_sumode(struct sbi_trap_regs *regs)
{
	const char *msg = "trap handler failed";
	ulong mcause = csr_read(CSR_MCAUSE);
	ulong mtval = csr_read(CSR_MTVAL), mtval2 = 0, mtinst = 0;
	struct sbi_trap_info trap;
	unsigned long hartid_local = csr_read(CSR_MHARTID);

	temporary_infos[hartid_local].cause = mcause;
	temporary_infos[hartid_local].tval = mtval;
	 
	
	if(mon_enclave_execution[hartid_local]){
		//We call the handler of keystone in case we are coming in from an enclave
		sscratch_double_save_enclave[hartid_local] = regs->sscratch;
		sbi_trap_handler_keystone_enclave(regs);
		
	} else{
		sscratch_double_save[hartid_local] = regs->sscratch;
	}

	struct sbi_trap_regs temp = {0};

	temporary_infos[hartid_local].cause = mcause;
	temporary_infos[hartid_local].tval = mtval;
	unsigned long timerval = 0;

	if (mcause & (1UL << (__riscv_xlen - 1))) {
		mcause &= ~(1UL << (__riscv_xlen - 1));
		switch (mcause) {
		case IRQ_M_TIMER:
		break;
		case IRQ_M_SOFT:
			mon_ipi_check(hartid_local);
			break;
		default:
			sbi_printf("[SM] Unhandled external interrupt (Core %d)\n", hartid_local);
			msg = "unhandled external interrupt";
			goto trap_error;
		};
		regs->mscratch = OSBI_mscratch[hartid_local];
		
		register unsigned long a0 asm("a0") = regs;
		asm("call _mon_exit_to_osbi" : : "r"(a0));
		__builtin_unreachable();
	}

	if(mcause == CAUSE_SUPERVISOR_ECALL || mcause == CAUSE_MACHINE_ECALL){
		ulong ecall_ext = regs->a7;
		if(ecall_ext == SBI_EXT_EXPERIMENTAL_KEYSTONE_ENCLAVE){
			ulong ecall_func = regs->a6;
			unsigned long out_val;
            struct sbi_trap_info out_trap;
			unsigned long ret = 0;
			
			ret = sbi_ecall_keystone_enclave_handler(ecall_ext, ecall_func, regs, &out_val, &out_trap);
			regs->a1 = out_val;
			regs->a0 = ret;

			regs->mepc = regs->mepc + 4;

			regs->sscratch = sscratch_double_save_enclave[hartid_local];
			
			
			register unsigned long a0 asm("a0") = regs;
			asm("call _mon_exit_to_su" : : "r"(a0));//return without invoking OSBI

		} else{
			unsigned long hartid = csr_read(CSR_MHARTID);
			mon_ecall_enter(regs, hartid);
			regs->mscratch = OSBI_mscratch[hartid_local];
			
			register unsigned long a0 asm("a0") = regs;
			asm("call _mon_exit_to_osbi" : : "r"(a0));
		}
	} else{
		regs->mscratch = OSBI_mscratch[hartid_local];
		
		register unsigned long a0 asm("a0") = regs;
		asm("call _mon_exit_to_osbi" : : "r"(a0));
	}
	regs->mscratch = OSBI_mscratch[hartid_local];
	
	register unsigned long a0 asm("a0") = regs;
	asm("call _mon_exit_to_osbi" : : "r"(a0));
	

trap_error:
	sbi_trap_error(msg, 0, mcause, mtval, mtval2, mtinst, regs);
	return regs;
}

static volatile unsigned int SU_started[5] = {0};

static volatile atomic_t coldboot_lottery_start = ATOMIC_INITIALIZER(0);


struct sbi_trap_regs *mon_trap_return_osbi(struct sbi_trap_regs *regs){
	ulong hartid = csr_read(CSR_MHARTID);
	const char *msg = "trap handler failed";
	ulong mcause = temporary_infos[hartid].cause;
	ulong mtval = csr_read(CSR_MTVAL), mtval2 = 0, mtinst = 0;

	if(mon_enclave_execution[hartid]){
		regs->sscratch = sscratch_double_save_enclave[hartid];
	} else{
		regs->sscratch = sscratch_double_save[hartid];
	}

	if(!SU_started[hartid]){ //first re-entry into Monitor => boot OS
		for (size_t i = 0; i < 5; i++)
		{
			if(SU_started[i]){
				sbi_printf("[SM] Other core already started; proceeding now... HARTID: %d, MEPC: %lx\n", hartid, regs->mepc);
				OSBI_mscratch[hartid] = regs->mscratch;
				SU_started[hartid]= 1;

				sbi_printf("MSCRATCH: 0x%lx, 0x%lx, 0x%lx, 0x%lx, 0x%lx\n", OSBI_mscratch[0], OSBI_mscratch[1], OSBI_mscratch[2], OSBI_mscratch[3], OSBI_mscratch[4]);

				register unsigned long a0 asm("a0") = regs->a0;
				register unsigned long a1 asm("a1") = regs->a1;
				register unsigned long a2 asm("a2") = regs->a2;

				asm("lla t6, _mon_enter_su; csrw mtvec, t6; mret" : : "r"(a0), "r"(a1), "r"(a2));

				__builtin_unreachable();
			}
		}
		OSBI_mscratch[hartid] = regs->mscratch;
		SU_started[hartid]= 1;
		(void) SU_started[hartid];
		sbi_printf("[SM] First entry into HOST kernel; proceeding now... HARTID: %d, MEPC: %lx\n", hartid, regs->mepc);
		sbi_printf("MSCRATCH: 0x%lx, 0x%lx, 0x%lx, 0x%lx\n", OSBI_mscratch[0], OSBI_mscratch[1], OSBI_mscratch[2], OSBI_mscratch[3]);		// register unsigned long a0 asm("a0") = regs->a0;

		register unsigned long a0 asm("a0") = regs->a0;
		register unsigned long a1 asm("a1") = regs->a1;
		register unsigned long a2 asm("a2") = regs->a2;

		asm("lla t6, _mon_enter_su; csrw mtvec, t6; mret" : : "r"(a0), "r"(a1), "r"(a2));
		__builtin_unreachable();
	}

	if(mon_enclave_execution[hartid]){
		sbi_sm_set_enclave_permissions();
	}

	if (mcause & (1UL << (__riscv_xlen - 1))) {
		mcause &= ~(1UL << (__riscv_xlen - 1));
		switch (mcause) {
		case IRQ_M_TIMER:
			break;
		case IRQ_M_SOFT:
			break;
		default:
			msg = "unhandled external interrupt";
			goto trap_error;
		};
		
		register unsigned long a0 asm("a0") = regs;
		asm("fence; call _mon_exit_to_su" : : "r"(a0));
	}

	switch (mcause) {
	case CAUSE_ILLEGAL_INSTRUCTION:
		break;
	case CAUSE_MISALIGNED_LOAD:
		break;
	case CAUSE_MISALIGNED_STORE:
		break;
	case CAUSE_SUPERVISOR_ECALL:
	case CAUSE_MACHINE_ECALL:
		temporary_registers[hartid].a0 = regs->a0;
		if(temporary_registers[hartid].a7 >= 0x00 && temporary_registers[hartid].a7 <= 0x0F){
			temporary_registers[hartid].mepc += 4; //VERY IMPORTANT AS ERYE USES LEGACY INSTRUCTIONS!
			break; //Legacy extensions don't have a second return value;
		}
		temporary_registers[hartid].a1 = regs->a1;
		temporary_registers[hartid].mepc += 4;
		break;
	case CAUSE_LOAD_ACCESS:
	case CAUSE_STORE_ACCESS:
		/* fallthrough */
	default:
		/* If the trap came from S or U mode, redirect it there */
		temporary_registers[hartid].mepc = regs->mepc;
		temporary_registers[hartid].mstatus = regs->mstatus;
		break;
	};

	

	if(mcause == CAUSE_SUPERVISOR_ECALL || mcause == CAUSE_MACHINE_ECALL){
		
		register unsigned long a0 asm("a0") = &temporary_registers[hartid];
		asm("fence; call _mon_exit_to_su" : : "r"(a0));
	}
	
	
	register unsigned long a0 asm("a0") = regs;
	asm("fence; call _mon_exit_to_su" : : "r"(a0));

trap_error:
		sbi_trap_error(msg, 0, mcause, mtval, mtval2, mtinst, regs);
	return NULL;
}


void sbi_trap_handler_keystone_enclave(struct sbi_trap_regs *regs)
{
	const char *msg = "trap handler failed";
	ulong mcause = csr_read(CSR_MCAUSE);
	ulong mtval = csr_read(CSR_MTVAL), mtval2 = 0, mtinst = 0;
	struct sbi_trap_info trap;

	if (mcause & (1UL << (__riscv_xlen - 1))) {
		mcause &= ~(1UL << (__riscv_xlen - 1));
		switch (mcause) {
		case IRQ_M_TIMER: {
      regs->mepc -= 4;
      sbi_sm_stop_enclave(regs, STOP_TIMER_INTERRUPT);
      regs->a0 = SBI_ERR_SM_ENCLAVE_INTERRUPTED;
      regs->mepc += 4;
			break;
                      }
		case IRQ_M_SOFT: {
      regs->mepc -= 4;
      sbi_sm_stop_enclave(regs, STOP_TIMER_INTERRUPT);
      regs->a0 = SBI_ERR_SM_ENCLAVE_INTERRUPTED;
      regs->mepc += 4;
			break;
                     }
		default:
			msg = "unhandled external interrupt";
			goto trap_error;
		};
		return;
	}

	if(mcause == CAUSE_SUPERVISOR_ECALL || mcause == CAUSE_MACHINE_ECALL){
		ulong ecall_ext = regs->a7;
		if(ecall_ext == SBI_EXT_EXPERIMENTAL_KEYSTONE_ENCLAVE){
			ulong ecall_func = regs->a6;
			unsigned long out_val;
            struct sbi_trap_info out_trap;
			unsigned long ret = 0;
			ret = sbi_ecall_keystone_enclave_handler(ecall_ext, ecall_func, regs, &out_val, &out_trap);
			regs->a1 = out_val;
			regs->a0 = ret;
			
			regs->mepc = regs->mepc + 4;
			
			register unsigned long a0 asm("a0") = regs;
			asm("call _mon_exit_to_su" : : "r"(a0));//return without invoking OSBI

		} else{
			unsigned long hartid = csr_read(CSR_MHARTID);
			mon_ecall_enter(regs, hartid);
			
			register unsigned long a0 asm("a0") = regs;
			asm("call _mon_exit_to_osbi" : : "r"(a0));
		}
	} else{
		
		register unsigned long a0 asm("a0") = regs;
		asm("call _mon_exit_to_osbi" : : "r"(a0));
	}
	
	register unsigned long a0 asm("a0") = regs;
	asm("call _mon_exit_to_osbi" : : "r"(a0));

trap_error:
		sbi_trap_error(msg, 0, mcause, mtval, mtval2, mtinst, regs);
}

typedef void (*trap_exit_t)(const struct sbi_trap_regs *regs);

void __noreturn sbi_trap_exit(struct sbi_trap_regs *regs, unsigned int target)
{
	ulong hartid = csr_read(CSR_MHARTID);
	if(target){
		mon_enclave_execution[hartid] = 1;
		(void) mon_enclave_execution[hartid];
		regs->sscratch = sscratch_double_save_enclave[hartid];
		unsigned long prev_mode = 0;
		prev_mode = (regs->mstatus & MSTATUS_MPP) >> MSTATUS_MPP_SHIFT;
	} else{
		regs->sscratch = sscratch_double_save[hartid];
		(void) regs->sscratch;
		mon_enclave_execution[hartid] = 0;
		(void) mon_enclave_execution[hartid];
		unsigned long prev_mode = 0;
		prev_mode = (regs->mstatus & MSTATUS_MPP) >> MSTATUS_MPP_SHIFT;
	}
	
	
	register unsigned long a0 asm("a0") = regs;
	asm("call _mon_exit_to_su" : : "r"(a0));

	__builtin_unreachable();
}
