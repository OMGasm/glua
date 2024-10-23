require('os')
require'io'

for i = 1, 5 do
	print(string.format("hello world %d", i))
end

print(os.time())

io.open("./vmtest.lua"):close()
local file = assert(io.open("./vmtest.lua"))

for line in file:lines() do
	print(line)
end
