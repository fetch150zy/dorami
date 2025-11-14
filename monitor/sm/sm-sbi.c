//******************************************************************************
// Copyright (c) 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE for license details.
//------------------------------------------------------------------------------
#include "sm-sbi.h"
#include "pmp.h"
#include "enclave.h"
#include "page.h"
#include "cpu.h"
#include "platform-hook.h"
#include "plugins/plugins.h"
#include <sbi/riscv_asm.h>
#include <sbi/sbi_console.h>

unsigned long sbi_sm_create_enclave(unsigned long* eid, uintptr_t create_args)
{
  struct keystone_sbi_create_t create_args_local;
  unsigned long ret;
  
  //osm_pmp_set(PMP_X | PMP_W); //SMAP-unlock
  osm_pmp_set(PMP_R | PMP_W); //SMAP-unlock
	//sbi_printf("SMAP-U: PMPCFG0: %lx\n", csr_read(CSR_PMPCFG0));
  ret = copy_enclave_create_args(create_args, &create_args_local);
  osm_pmp_set(PMP_X | PMP_W | PMP_R); //SMAP-Lock
  //sbi_printf("SMAP-L: PMPCFG0: %lx\n", csr_read(CSR_PMPCFG0));

  if (ret)
    return ret;

  ret = create_enclave(eid, create_args_local);
  //sbi_printf("EXIT-CE: PMPCFG0: %lx\n", csr_read(CSR_PMPCFG0));
  osm_pmp_set(PMP_X | PMP_W | PMP_R); //SMAP-Lock
  //sbi_printf("SMAP-L2: PMPCFG0: %lx\n", csr_read(CSR_PMPCFG0));
  return ret;
}

unsigned long sbi_sm_destroy_enclave(unsigned long eid)
{
  unsigned long ret;
  ret = destroy_enclave((unsigned int)eid);
  return ret;
}

unsigned long sbi_sm_run_enclave(struct sbi_trap_regs *regs, unsigned long eid)
{
  // sbi_printf("PMPADDR0: %lx\n", csr_read(CSR_PMPADDR0));
  // sbi_printf("PMPADDR1: %lx\n", csr_read(CSR_PMPADDR1));
	// sbi_printf("PMPADDR2: %lx\n", csr_read(CSR_PMPADDR2));
	// sbi_printf("PMPADDR3: %lx\n", csr_read(CSR_PMPADDR3));
	// sbi_printf("PMPADDR4: %lx\n", csr_read(CSR_PMPADDR4));
	// sbi_printf("PMPADDR5: %lx\n", csr_read(CSR_PMPADDR5));
	// sbi_printf("PMPADDR6: %lx\n", csr_read(CSR_PMPADDR6));
	// sbi_printf("PMPADDR7: %lx\n", csr_read(CSR_PMPADDR7));
  // sbi_printf("PMPCFG0: %lx\n", csr_read(CSR_PMPCFG0));
  regs->a0 = run_enclave(regs, (unsigned int) eid);
  regs->mepc += 4;
  sbi_trap_exit(regs, 1);
  return 0;
}

unsigned long sbi_sm_resume_enclave(struct sbi_trap_regs *regs, unsigned long eid)
{
  unsigned long ret;
  ret = resume_enclave(regs, (unsigned int) eid);
  if (!regs->zero)
    regs->a0 = ret;
  regs->mepc += 4;

  sbi_trap_exit(regs, 1);
  return 0;
}

unsigned long sbi_sm_exit_enclave(struct sbi_trap_regs *regs, unsigned long retval)
{
  regs->a0 = exit_enclave(regs, cpu_get_enclave_id());
  regs->a1 = retval;
  regs->mepc += 4;
  sbi_trap_exit(regs, 0);
  return 0;
}

unsigned long sbi_sm_stop_enclave(struct sbi_trap_regs *regs, unsigned long request)
{
  regs->a0 = stop_enclave(regs, request, cpu_get_enclave_id());
  regs->mepc += 4;
  sbi_trap_exit(regs, 0);
  return 0;
}

extern unsigned long enclave_fix_access_permissions(enclave_id eid);

unsigned long sbi_sm_set_enclave_permissions(){
  return enclave_fix_access_permissions(cpu_get_enclave_id());
}

unsigned long sbi_sm_attest_enclave(uintptr_t report, uintptr_t data, uintptr_t size)
{
  unsigned long ret;
  ret = attest_enclave(report, data, size, cpu_get_enclave_id());
  return ret;
}

unsigned long sbi_sm_get_sealing_key(uintptr_t sealing_key, uintptr_t key_ident,
                       size_t key_ident_size)
{
  unsigned long ret;
  ret = get_sealing_key(sealing_key, key_ident, key_ident_size,
                         cpu_get_enclave_id());
  return ret;
}

unsigned long sbi_sm_random(void)
{
  return (unsigned long) platform_random();
}

unsigned long sbi_sm_call_plugin(uintptr_t plugin_id, uintptr_t call_id, uintptr_t arg0, uintptr_t arg1)
{
  unsigned long ret;
  ret = call_plugin(cpu_get_enclave_id(), plugin_id, call_id, arg0, arg1);
  return ret;
}
