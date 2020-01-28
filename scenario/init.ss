*init

@setlayer=soundLayer
@setlayer=bgimgLayer
@setlayer=fgimgLayer
@setlayer=imgLayer
@setlayer=labelLayer
@setlayer=videoLayer
# any layer above this will not recieve (click/touch) input by default; has to be handled below
@setlayer=buttonLayer

@macro=*menu:init
@call=scriptdump

@print=init_complete
@jump=*ready


