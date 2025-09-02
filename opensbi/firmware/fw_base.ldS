/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Anup Patel <anup.patel@wdc.com>
 */

	/*. = FW_TEXT_START;*/
	. = 0x80000000;
	/* Don't add any section between FW_TEXT_START and _fw_start */

	/* We place the Code section of the Primary here, size is 0x40000*/
	.newRAWcode :
	{
		PROVIDE(_newRAWcode_start = .);
		*(.monitor_raw_code*)
		/* . = ALIGN(8); */
		PROVIDE(_newRAWcode_end = .);
	}

	. = 0x80040000;
	

	PROVIDE(_fw_start = .);

	. = ALIGN(0x1000); /* Need this to create proper sections */

	/* Beginning of the code section */

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

	/* End of the code sections */

	. = ALIGN(0x1000); /* Ensure next section is page aligned */
	
	/* Beginning of the read-only data sections */

	PROVIDE(_rodata_start = .);

	.rodata :
	{
		*(.rodata .rodata.*)
		. = ALIGN(8);
	}

	. = ALIGN(0x1000); /* Ensure next section is page aligned */

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

	/* End of the read-only data sections */

	/*
	 * PMP regions must be to be power-of-2. RX/RW will have separate
	 * regions, so ensure that the split is power-of-2.
	 */
	/* . = ALIGN(1 << LOG2CEIL((SIZEOF(.rodata) + SIZEOF(.text)
				+ SIZEOF(.dynsym) + SIZEOF(.rela.dyn)))); */

	/*. = FW_DATA_START;*/
	/*. = 0x80080000;*/

	. = 0x8007F000; /*Here starts the jumppad back to the primary, first the end-page then the page with the jumppad , consequently will alsop be 0x40000*/

	/*0x80080000 is the jumppad back to primary*/

	.jpc : {
		PROVIDE(_jpc_start = .);
		*(.return_to_primary*)
		PROVIDE(_jpc_end = .);
	}

	. = 0x800C0000;

	PROVIDE(_fw_data_start = .);


	PROVIDE(_fw_rw_start = .);

	/* Beginning of the read-write data sections */

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

	. = ALIGN(0x1000); /* Ensure next section is page aligned */

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

	/* End of the read-write data sections */

	. = ALIGN(0x1000); /* Need this to create proper sections */

	PROVIDE(_fw_end = .);



	/*. = 0x8007e000;*/ /* the last page before the payload */

	. = 0x800De000; /* the last page before the payload */

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

/* . = 0x80080000;
	.newRAW :
	{
		PROVIDE(_newRAW_start = .);
		*(.monitor_raw*)
		. = ALIGN(8);
		PROVIDE(_newRAW_end = .);
	} */

. = 0x80100000;
	.newRAWdata :
	{
		PROVIDE(_newRAWdata_start = .);
		*(.monitor_raw_data*)
		. = ALIGN(8);
		PROVIDE(_newRAWdata_end = .);
	}