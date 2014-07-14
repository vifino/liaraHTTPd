--print('<script src="myScript.js"></script>')
function loadJS(loc) print('<script type="text/javascript" src="'..loc..'"> </script>') end
loadJS("test")
