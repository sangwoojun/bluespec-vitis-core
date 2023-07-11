BSCFLAGS = -show-schedule -aggressive-conditions 
BSCFLAGS_SYNTH = -bdir ./obj -vdir ./obj/verilog -simdir ./obj -info-dir ./obj -fdir ./obj 

MODULEPATH=./intersection

all:
	mkdir -p obj
	mkdir -p obj/verilog
	bsc  $(BSCFLAGS) $(BSCFLAGS_SYNTH) -remove-dollar -p +:$(MODULEPATH) -verilog -u -g mkKernelTop KernelTop.bsv 
	cd obj/verilog/;bash ../../verilogcopy.sh
	cp *.v ./obj/verilog/
	
clean:
	rm -r obj
