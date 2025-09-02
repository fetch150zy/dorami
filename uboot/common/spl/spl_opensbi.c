// SPDX-License-Identifier: GPL-2.0+
/*
 * Copyright (C) 2019 Fraunhofer AISEC,
 * Lukas Auer <lukas.auer@aisec.fraunhofer.de>
 *
 * Based on common/spl/spl_atf.c
 */
#include <common.h>
#include <cpu_func.h>
#include <errno.h>
#include <hang.h>
#include <image.h>
#include <spl.h>
#include <asm/global_data.h>
#include <asm/smp.h>
#include <opensbi.h>
#include <linux/libfdt.h>

DECLARE_GLOBAL_DATA_PTR;

struct fw_dynamic_info opensbi_info;

static int spl_opensbi_find_uboot_node(void *blob, int *uboot_node)
{
	int fit_images_node, node;
	const char *fit_os;

	fit_images_node = fdt_path_offset(blob, "/fit-images");
	if (fit_images_node < 0)
		return -ENODEV;

	fdt_for_each_subnode(node, blob, fit_images_node) {
		fit_os = fdt_getprop(blob, node, FIT_OS_PROP, NULL);
		if (!fit_os)
			continue;

		if (genimg_get_os_id(fit_os) == IH_OS_U_BOOT) {
			*uboot_node = node;
			return 0;
		}
	}

	return -ENODEV;
}

#define OPCODE_MASK 0x7F
#define FUNC3_MASK  0x7
//#define RD_MASK     0xF80
#define RD_MASK     0xFFF
//#define IMM_MASK    0xFFF
#define IMM_MASK    0x1F

// Define error codes
#define ERROR_RD_RANGE          1
#define ERROR_RD_VALUE          2
#define ERROR_UIMM_NONZERO      3


void spl_check_pmp(){

	size_t size = 0x40000;

	// uint8_t * memory = 0x80000000;
	uint8_t * memory = 0x80040000;

	// unsigned long mpt = 0x80000000;
	unsigned long mpt = 0x80000000;

	size_t i;
    for (i = 0; i < size; i += 4) {
        if (i + 4 > size) {
            // Incomplete instruction in the last few bytes
            return 0;
        }

        uint32_t instruction = *(uint32_t*)(memory + i);

        // Extract opcode, func3, rd, and uimm
        uint32_t opcode = instruction & OPCODE_MASK;
        uint32_t func3 = (instruction >> 12) & FUNC3_MASK;
        uint32_t rd = (instruction >> 20) & RD_MASK;
        uint32_t uimm = (instruction >> 15) & IMM_MASK;

        // Check opcode
        if (opcode == 115) {  // 0b1110011
            if (func3 == 1 || func3 == 2 || func3 == 3 || func3 == 6 || func3 == 7) {
                // Check rd range
                if ((rd >= 0x3a0 && rd <= 0x3ef) || rd == 0x305 || rd == 0x747) {
                    pr_err("Invalid Instruction detected at %lx\n", mpt + i);
					while (1); //stop the boot
                }
            } else if (func3 == 5) {
                // Check rd range and uimm
                if ((rd == 0x3a0 && uimm != 0) || (rd >= 0x3a0 && rd <= 0x3ef) || rd == 0x305 || rd == 0x747) {
                    pr_err("Invalid range detected at %lx\n", mpt + i);
					while (1); //stop the boot
                }
                
            }
        }
    }
}

void spl_invoke_opensbi(struct spl_image_info *spl_image)
{
	int ret, uboot_node;
	ulong uboot_entry;
	void (*opensbi_entry)(ulong hartid, ulong dtb, ulong info);

	if (!spl_image->fdt_addr) {
		pr_err("No device tree specified in SPL image\n");
		hang();
	}

	/* Find U-Boot image in /fit-images */
	ret = spl_opensbi_find_uboot_node(spl_image->fdt_addr, &uboot_node);
	if (ret) {
		pr_err("Can't find U-Boot node, %d\n", ret);
		hang();
	}

	/* Get U-Boot entry point */
	ret = fit_image_get_entry(spl_image->fdt_addr, uboot_node, &uboot_entry);
	if (ret)
		ret = fit_image_get_load(spl_image->fdt_addr, uboot_node, &uboot_entry);

	/* Prepare opensbi_info object */
	opensbi_info.magic = FW_DYNAMIC_INFO_MAGIC_VALUE;
	opensbi_info.version = FW_DYNAMIC_INFO_VERSION;
	opensbi_info.next_addr = uboot_entry;
	opensbi_info.next_mode = FW_DYNAMIC_INFO_NEXT_MODE_S;
	opensbi_info.options = CONFIG_SPL_OPENSBI_SCRATCH_OPTIONS;
	opensbi_info.boot_hart = gd->arch.boot_hart;

	opensbi_entry = (void (*)(ulong, ulong, ulong))spl_image->entry_point;
	pr_err("[SPL] Entering OSBI, Func: 0x%p, Hart: %ld, FDT addr: 0x%lx, OSBI info: 0x%lx\n", 
				opensbi_entry, gd->arch.boot_hart, (ulong)spl_image->fdt_addr, (ulong)&opensbi_info); //we're actually entering monitor here
	spl_check_pmp();
	invalidate_icache_all();

#ifdef CONFIG_SPL_SMP
	/*
	 * Start OpenSBI on all secondary harts and wait for acknowledgment.
	 *
	 * OpenSBI first relocates itself to its link address. This is done by
	 * the main hart. To make sure no hart is still running U-Boot SPL
	 * during relocation, we wait for all secondary harts to acknowledge
	 * the call-function request before entering OpenSBI on the main hart.
	 * Otherwise, code corruption can occur if the link address ranges of
	 * U-Boot SPL and OpenSBI overlap.
	 */
	pr_err("[SPL] Starting SMP boot...\n");
	ret = smp_call_function((ulong)spl_image->entry_point,
				(ulong)spl_image->fdt_addr,
				(ulong)&opensbi_info, 1);
	if (ret)
		hang();
#endif
	pr_err("[SPL] Starting single core boot...\n");
	opensbi_entry(gd->arch.boot_hart, (ulong)spl_image->fdt_addr,
		      (ulong)&opensbi_info);
}
