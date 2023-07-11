ROOTDIR=../
BSVPATH=$(ROOTDIR)/kernel:$(ROOTDIR)/kernel/intersection/

BSIM_DIR=./bsim/
BSIM_CPPFILES=bdpi.cpp

BSCFLAGS = -show-schedule -aggressive-conditions 
BSCFLAGS_BSIM = -bdir $(BSIM_DIR) -vdir $(BSIM_DIR) -simdir $(BSIM_DIR) -info-dir $(BSIM_DIR) -fdir $(BSIM_DIR) -D BSIM -l pthread

bsim: $(wildcard ./$(ROOTDIR)/kernel/*.bsv) $(wildcard ./$(ROOTDIR)/kernel/intersection/*.bsv)

	mkdir -p $(BSIM_DIR)
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) -p +:$(BSVPATH) -sim -u -g mkSimTop SimTop.bsv 
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) -sim -e mkSimTop -o $(BSIM_DIR)/bsim $(BSIM_DIR)/*.ba $(BSIM_CPPFILES)

runsim:
	./bsim/bsim | tee -a output.log

clean:
	rm -rf bsim
	rm -rf bdpi.o
	rm -rf output.log
