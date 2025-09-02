

code_offset = 0x0
code_size = 0x40000
data_offset = 0x100000
data_size = 0x40000

binary_file = open("monitor.bin", "rb")

binary_file.seek(code_offset)
_code = binary_file.read(code_size)

code_opt = open("monitor_code.bin", "wb")
code_opt.write(_code)
code_opt.close()

binary_file.seek(data_offset)
_data = binary_file.read(data_size)

data_opt = open("monitor_data.bin", "wb")
data_opt.write(_data)
data_opt.close()

binary_file.close()