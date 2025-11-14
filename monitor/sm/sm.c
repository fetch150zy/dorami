//******************************************************************************
// Copyright (c) 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE for license details.
//------------------------------------------------------------------------------
//#include "ipi.h"
#include "sm.h"
#include "pmp.h"
#include "crypto.h"
#include "enclave.h"
#include "platform-hook.h"
//#include "sm-sbi-opensbi.h"
#include "../sbi/riscv_asm.h"
#include "../sbi/sbi_string.h"
#include "../sbi/riscv_locks.h"
#include "../sbi/riscv_barrier.h"
#include "../sbi/sbi_console.h"

#include <mon_utils.h>

#define MDSIZE  64

#define SIGNATURE_SIZE  64
#define PRIVATE_KEY_SIZE  64 // includes public key
#define PUBLIC_KEY_SIZE 32

typedef unsigned char byte;

static int sm_init_done = 0;
//static int sm_region_id = 0, os_region_id = 0;
static int sp1_region_id = 0;
static int dev_region_id = 0, sm_code_region_id = 0, sm_data_region_id = 0, os_region_id = 0;

//For the moment, we perform the initialization here...
static int tm_code_region_id = 0, tm_data_region_id = 0;



unsigned char sm_hash[MDSIZE] = { 0, };
unsigned char sm_signature[SIGNATURE_SIZE] = { 0, };
unsigned char sm_public_key[PUBLIC_KEY_SIZE] = { 0, };
unsigned char sm_private_key[PRIVATE_KEY_SIZE] = { 0, };
unsigned char dev_public_key[PUBLIC_KEY_SIZE] = { 0, };

int osm_pmp_set(uint8_t perm)
{
  /* in case of OSM, PMP cfg is exactly the opposite.*/
  return pmp_set_keystone(os_region_id, perm);
}

int reg_sp1_init(){
  int region = -1;
  int ret = pmp_region_init_atomic(REGION_SP1_CODE_BASE, REGION_SP1_CODE_SIZE, PMP_PRI_ANY, &region, 0);
  if(ret)
    return -1;

  return region;
}

int reg_device_init(){
  int region = -1;
  int ret = pmp_region_init_atomic(REGION_DEVICE_BASE, REGION_DEVICE_SIZE, PMP_PRI_ANY, &region, 0);
  if(ret)
    return -1;

  return region;
}

int reg_tm_code_init(){
  int region = -1;
  int ret = pmp_region_init_atomic(REGION_TM_CODE_BASE, REGION_TM_CODE_SIZE, PMP_PRI_TOP, &region, 0);
  if(ret)
    return -1;

  return region;
}

int reg_tm_data_init(){
  int region = -1;
  int ret = pmp_region_init_atomic(REGION_TM_DATA_BASE, REGION_TM_DATA_SIZE, PMP_PRI_ANY, &region, 0);
  if(ret)
    return -1;

  return region;
}

int reg_smm_code_init(){
  int region = -1;
  int ret = pmp_region_init_atomic(REGION_SMM_CODE_BASE, REGION_SMM_CODE_SIZE, PMP_PRI_ANY, &region, 0);
  if(ret)
    return -1;

  return region;
}

int reg_smm_data_init(){
  int region = -1;
  int ret = pmp_region_init_atomic(REGION_SMM_DATA_BASE, REGION_SMM_DATA_SIZE, PMP_PRI_ANY, &region, 0);
  if(ret)
    return -1;

  return region;
}

int smm_init()
{
  int region = -1;
  int ret = pmp_region_init_atomic(SMM_BASE, SMM_SIZE, PMP_PRI_TOP, &region, 0);
  if(ret)
    return -1;

  return region;
}

int osm_init()
{
  int region = -1;
  int ret = pmp_region_init_atomic(0, -1UL, PMP_PRI_BOTTOM, &region, 1);
  if(ret)
    return -1;

  return region;
}

void sm_sign(void* signature, const void* data, size_t len)
{
  sign(signature, data, len, sm_public_key, sm_private_key);
}

#define SEALING_KEY_SIZE 128

int sm_derive_sealing_key(unsigned char *key, const unsigned char *key_ident,
                          size_t key_ident_size,
                          const unsigned char *enclave_hash)
{
  unsigned char info[MDSIZE + key_ident_size];

  sbi_memcpy(info, enclave_hash, MDSIZE);
  sbi_memcpy(info + MDSIZE, key_ident, key_ident_size);

  /*
   * The key is derived without a salt because we have no entropy source
   * available to generate the salt.
   */
  return kdf(NULL, 0,
             (const unsigned char *)sm_private_key, PRIVATE_KEY_SIZE,
             info, MDSIZE + key_ident_size, key, SEALING_KEY_SIZE);
}

static void sm_print_hash(void)
{
  for (int i=0; i<MDSIZE; i++)
  {
    sbi_printf("%02x", (char) sm_hash[i]);
  }
  sbi_printf("\n");
}

/*
void sm_print_cert()
{
	int i;

	printm("Booting from Security Monitor\n");
	printm("Size: %d\n", sanctum_sm_size[0]);

	printm("============ PUBKEY =============\n");
	for(i=0; i<8; i+=1)
	{
		printm("%x",*((int*)sanctum_dev_public_key+i));
		if(i%4==3) printm("\n");
	}
	printm("=================================\n");

	printm("=========== SIGNATURE ===========\n");
	for(i=0; i<16; i+=1)
	{
		printm("%x",*((int*)sanctum_sm_signature+i));
		if(i%4==3) printm("\n");
	}
	printm("=================================\n");
}
*/

void sm_init(bool cold_boot)
{
  

	// initialize SMM
  if (cold_boot) {
    /* only the cold-booting hart will execute these */
    sbi_printf("[SM] Initializing ... hart [%lx]\n", csr_read(CSR_MHARTID));

    //sbi_ecall_register_extension(&ecall_keystone_enclave);

    tm_code_region_id = reg_tm_code_init();
    if(tm_code_region_id < 0) {
      sbi_printf("[SM] intolerable error - failed to initialize TM_CODE memory\n");
      sbi_hart_hang();
    }

    tm_data_region_id = reg_tm_data_init();
    if(tm_data_region_id < 0) {
      sbi_printf("[SM] intolerable error - failed to initialize TM_DATA memory\n");
      sbi_hart_hang();
    }

    sm_code_region_id = reg_smm_code_init();
    if(sm_code_region_id < 0) {
      sbi_printf("[SM] intolerable error - failed to initialize FW_CODE memory\n");
      sbi_hart_hang();
    }

    sm_data_region_id = reg_smm_data_init();
    if(sm_data_region_id < 0) {
      sbi_printf("[SM] intolerable error - failed to initialize FW_DATA memory\n");
      sbi_hart_hang();
    }

    //activate if more than 8 pmp regions are available
    // sp1_region_id = reg_sp1_init();
    // if(sp1_region_id < 0) {
    //   sbi_printf("[SM] intolerable error - failed to initialize SP_CODE memory\n");
    //   sbi_hart_hang();
    // }

    dev_region_id = reg_device_init();
    if(dev_region_id < 0) {
      sbi_printf("[SM] intolerable error - failed to initialize DEV memory\n");
      sbi_hart_hang();
    }

    os_region_id = osm_init();
    if(os_region_id < 0) {
      sbi_printf("[SM] intolerable error - failed to initialize OS memory\n");
      sbi_hart_hang();
    }


    // Init the enclave metadata
    enclave_init_metadata();

    sm_init_done = 1;
    mb();
  }

  /* wait until cold-boot hart finishes */
  while (!sm_init_done)
  {
    mb();
  }

    /*******************************************************************/

  epmp_rlb();

  /* below are executed by all harts */
  pmp_init();

  pmp_set_keystone(tm_code_region_id, EPMP_M_RX);
  pmp_set_keystone(tm_data_region_id, EPMP_M_RW);
  pmp_set_keystone(sm_code_region_id, PMP_NO_PERM);
  pmp_set_keystone(sm_data_region_id, PMP_NO_PERM);
  // pmp_set_keystone(dev_region_id, EPMP_ALL_RW); //activate if more than 8 pmp regions are available
  pmp_set_keystone(sp1_region_id, PMP_NO_PERM);
  
  pmp_set_keystone(os_region_id, EPMP_ALL_RW);

  epmp_activate();

  pmp_set_keystone(dev_region_id, EPMP_ALL_RW);
  pmp_set_keystone(tm_code_region_id, EPMP_M_RX);
  pmp_set_keystone(tm_data_region_id, EPMP_M_RW);
  pmp_set_keystone(sm_code_region_id, PMP_NO_PERM);
  pmp_set_keystone(sm_data_region_id, PMP_NO_PERM);
  pmp_set_keystone(dev_region_id, EPMP_ALL_RW);
  // pmp_set_keystone(sp1_region_id, PMP_NO_PERM); //activate if more than 8 pmp regions are available
  pmp_set_keystone(os_region_id, EPMP_ALL_RW);

  // asm("li t6, 0x20027FFF; csrrw t6, pmpaddr8, t6; li t6, 1F; csrrw t6, pmpcfg2, t6;" : : );
  //activate if more than 8 pmp regions are available

  /*******************************************************************/

  sbi_printf("[SM] Keystone security monitor has been initialized!\n");

   sm_print_hash();

  if(csr_read(CSR_MHARTID) != 0x00){
    //sbi_printf("[SM] Now enabling user-mode-counter...\n");
    csr_write(CSR_SCOUNTEREN, 0x7);
    //sbi_printf("[SM] SCOUNTEREN Value: %lx\n", csr_read(CSR_SCOUNTEREN));
  }

  

  return;
  // for debug
  // sm_print_cert();
}
