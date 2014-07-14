function alert2(text)
	print('alert('..(text or "")..');')
	js('alert("'..(text or "")..'");')
end
print("hai")
alert2("test")
print("<h1>test</h1>")
return testing