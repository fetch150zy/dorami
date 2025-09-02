//******************************************************************************
// Copyright (c) 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE for license details.
//------------------------------------------------------------------------------
#ifndef sm_h
#define sm_h

#include "../sbi/sbi_types.h"
#include "pmp.h"
//#include "sm-sbi.h"
#include "../sbi/riscv_encoding.h"

#include "sm_call.h"
#include "sm_err.h"

#define REGION_DEVICE_BASE 0x0
#define REGION_DEVICE_SIZE 0x80000000
#define REGION_SMM_CODE_BASE  0x80040000
#define REGION_SMM_CODE_SIZE  0x40000
#define REGION_SMM_DATA_BASE  0x800C0000
#define REGION_SMM_DATA_SIZE  0x40000

#define REGION_SP1_CODE_BASE  0x80080000
#define REGION_SP1_CODE_SIZE  0x40000

//Temporary workaround
#define REGION_TM_CODE_BASE  0x80000000
#define REGION_TM_CODE_SIZE  0x40000
#define REGION_TM_DATA_BASE  0x80100000
#define REGION_TM_DATA_SIZE  0x40000

#define SMM_BASE  0x80000000
#define SMM_SIZE  0x200000
void sm_init(bool cold_boot);

/* platform specific functions */
#define ATTESTATION_KEY_LENGTH  64
void sm_retrieve_pubkey(void* dest);
void sm_sign(void* sign, const void* data, size_t len);
int sm_derive_sealing_key(unsigned char *key,
                          const unsigned char *key_ident,
                          size_t key_ident_size,
                          const unsigned char *enclave_hash);

int osm_pmp_set(uint8_t perm);
#endif
