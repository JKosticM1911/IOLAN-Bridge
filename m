
SDK_DIR = $(CURDIR)/../..
ARCH:=arm
include $(SDK_DIR)/MAKE_DEFS

LIBS=-lsdk  
LIBS_SSL=-lssl -lcrypto

CFLAGS += $(SDK_CFLAGS)
# Comment out the line below if you want to turn on debug syslogs 
# for sample applications
#CFLAGS += -DSDK_APPS_DEBUG
LD_CCFLAGS = $(SDK_LD_CCFLAGS)

# shared library flags (assumes gcc)
DLFLAGS= -fPIC -shared

all: middleman

middleman: middleman.o
	$(CC) -W -Wall $(CFLAGS) $(LD_CCFLAGS) $(LIBS) -o middleman middleman.o
	$(STRIP) middleman

clean:
	-rm -f *.o io middleman makefile.depend

