# Dorami Artifact
This repo contains the Dorami code from the artifact evaluation. 

```
make -C opensbi \
		PLATFORM=generic \
		FW_TEXT_START=0x80800000 \
		FW_FDT_PATH=./dts/virt.dtb \
		FW_PAYLOAD_PATH=./linux/arch/riscv/boot/Image \
		FW_PAYLOAD_OFFSET=0x200000
```