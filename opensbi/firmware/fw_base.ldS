/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Anup Patel <anup.patel@wdc.com>
 */

	/* Monitor .text start, size: 0x40000 */
	. = 0x80000000;
	.newRAWcode :
	{
		PROVIDE(_newRAWcode_start = .);
		*(.monitor_raw_code*)
		. = ALIGN(8);
		PROVIDE(_newRAWcode_end = .);
	}

	/* OpenSBI .text start, size: 0x40000 */
	. = 0x80040000;
	PROVIDE(_fw_start = .);
	. = ALIGN(0x1000);

	.text :
 	{
		PROVIDE(_text_start = .);
		*(.entry)
		. = ALIGN(0x2000);
		*(.jumper)
		. = ALIGN(0x1000);
		*(.osbi_entrypoint)
		*(.text)
		. = ALIGN(8);
		PROVIDE(_text_end = .);
	}
	. = ALIGN(0x1000);
	

	PROVIDE(_rodata_start = .);
	.rodata :
	{
		*(.rodata .rodata.*)
		. = ALIGN(8);
	}
	. = ALIGN(0x1000);

	.dynsym : {
		PROVIDE(__dyn_sym_start = .);
		*(.dynsym)
		PROVIDE(__dyn_sym_end = .);
	}

	.rela.dyn : {
		PROVIDE(__rel_dyn_start = .);
		*(.rela*)
		. = ALIGN(8);
		PROVIDE(__rel_dyn_end = .);
	}
	PROVIDE(_rodata_end = .);


	/* OpenSBI .text last page */
	. = 0x8007F000;
	.jpc : {
		PROVIDE(_jpc_start = .);
		*(.osbi_last_page*)
		PROVIDE(_jpc_end = .);
	}


	. = 0x800C0000;
	PROVIDE(_fw_data_start = .);
	PROVIDE(_fw_rw_start = .);

	.data :
	{
		PROVIDE(_data_start = .);

		*(.sdata)
		*(.sdata.*)
		*(.data)
		*(.data.*)
		*(.readmostly.data)
		*(*.data)
		. = ALIGN(8);

		PROVIDE(_data_end = .);
	}
	. = ALIGN(0x1000);

	.bss :
	{
		PROVIDE(_bss_start = .);
		*(.sbss)
		*(.sbss.*)
		*(.bss)
		*(.bss.*)
		. = ALIGN(8);
		PROVIDE(_bss_end = .);
	}
	. = ALIGN(0x1000);

	PROVIDE(_fw_end = .);


	 /* the last page before the payload */
	. = 0x800De000;

	/* ## manufacturer_keys : */
	/* 32 Bytes : manufacturer public key */
	PROVIDE( sanctum_m_public_key = . );
	. += 0x20;
	/* 32 Bytes : device public key */
	PROVIDE( sanctum_dev_public_key = . );
	. += 0x20;
	/* 64 Bytes : device secret key */
	PROVIDE( sanctum_dev_secret_key = . );
	. += 0x40;

	/* ## security_monitor_keys : */
	/* 64 Bytes : security monitor hash */
	PROVIDE( sanctum_sm_hash = . );
	. += 0x40;
	/* 32 Bytes : security monitor public key */
	PROVIDE( sanctum_sm_public_key = . );
	. += 0x20;
	/* 64 Bytes : security monitor secret key */
	PROVIDE( sanctum_sm_secret_key = . );
	. += 0x40;
	/* 64 Bytes : security monitor's signature by device */
	PROVIDE( sanctum_sm_signature = . );
	. += 0x40;


	. = 0x80100000;
	.newRAWdata :
	{
		PROVIDE(_newRAWdata_start = .);
		*(.monitor_raw_data*)
		. = ALIGN(8);
		PROVIDE(_newRAWdata_end = .);
	}
