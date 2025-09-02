
#include <sbi/sbi_console.h>
#include <sbi/riscv_asm.h>
#include <sbi/riscv_io.h>
#include "ipi.h"
#include "pmp.h"

static struct mon_ipi_cand IPI_updates[5] = {0};

unsigned int mon_ipi_check(unsigned long hartid){
  unsigned int ret = 0;
  asm("fence");
  for (size_t i = 0; i < 5; i++)
  {
    if((IPI_updates[i].data_valid[hartid] > 0) && (IPI_updates[i].data_ready[hartid] == 0)){
      if(IPI_updates[i].type == 0){
        pmp_set_keystone(IPI_updates[i].region_idx, (uint8_t) IPI_updates[i].perm);
      } else{
        pmp_unset(IPI_updates[i].region_idx);
      }
      IPI_updates[i].data_ready[hartid] = 1;
    }
  }
  return 0;
}

static unsigned int *msip = 0x2000000;

static void mswi_ipi_send(unsigned int target_hart)
{
	/* Set ACLINT IPI */

	writel(1, &msip[target_hart ]);
}

void mon_send_sync_ipi(int region_idx, int type, unsigned char perm){
  unsigned long hartid = csr_read(CSR_MHARTID);
  IPI_updates[hartid].perm = perm;
  IPI_updates[hartid].region_idx = region_idx;
  IPI_updates[hartid].type = type;
  for (size_t i = 1; i < 5; i++)//we start at 1 because core 0 is not used by us...
  {
    if(i == hartid){
      IPI_updates[hartid].data_ready[i] = 1;
      continue;
    }
    IPI_updates[hartid].data_valid[i] = 1;
    asm("fence");
    mswi_ipi_send(i);
  }


  while (
    IPI_updates[hartid].data_ready[1] == 0 || //check for all cores
    IPI_updates[hartid].data_ready[2] == 0 ||
    IPI_updates[hartid].data_ready[3] == 0 ||
    IPI_updates[hartid].data_ready[4] == 0 
  )
  {
    asm("fence");
    for (size_t i = 0; i < 0x2000000; i++) //first: busy loop
    {
      asm("nop");
    }

    for (size_t i = 1; i < 5; i++)// Now we check again, and if it still did not wen through, we resend an ipi
    {
      if(i == hartid){
        continue;
      }
      if(IPI_updates[hartid].data_ready[i] == 0){
        mswi_ipi_send(i);
      }
    }

    //TODO: Add Deadlock resolver, i.e. checking if there is an IPI waiting for us...
    
  }

  IPI_updates[hartid].perm = 0;
  IPI_updates[hartid].region_idx = 0;
  IPI_updates[hartid].type = 0;
  for (size_t i = 1; i < 5; i++)//we start at 1 because core 0 is not used by us...
  {
    IPI_updates[hartid].data_valid[i] = 0;
    IPI_updates[hartid].data_ready[i] = 0;
  }
  asm("fence");;

  
}


