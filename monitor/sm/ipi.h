#ifndef __PMP_IPI_H__
#define __PMP_IPI_H__

#define SBI_PMP_IPI_TYPE_SET    0
#define SBI_PMP_IPI_TYPE_UNSET  1

struct mon_ipi_cand { //We have one of this PER SENDER core
  unsigned char data_valid[5];//here the sender sets the datapoint to 1 if it requests a IPI to that specific core
  unsigned char data_ready[5];//here that specific core acknowledges the interrupt - sender afterwards resets it to 0
  int region_idx;
  int type;
  unsigned char perm;
};

unsigned int mon_ipi_check(unsigned long hartid);
static void mswi_ipi_send(unsigned int target_hart);
void mon_send_sync_ipi(int region_idx, int type, unsigned char perm);

#endif
