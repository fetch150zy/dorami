
#ifndef __MON_INIT_H__
#define __MON_INIT_H__

#include "mon_scratch.h"
#include "sbi/sbi_types.h"


void __noreturn mon_init(unsigned long inputA, unsigned long inputB, struct mon_scratch *scratch);

#endif
