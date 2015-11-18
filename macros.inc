##############################################################################
# MAC_IBM:		MAC OS X Apple with IBM Compiler.
##############################################################################
F90_SER = gfortran
F90_OMP =
F90_MPI = mpif90
FLAGS_OPT = -O
FLAGS_MSC = -w -fno-second-underscore
FLAGS90_MSC = -w -fno-second-underscore -ffree-line-length-none
FLAGS_SER =
FLAGS_OMP =
FLAGS_MPI =
NETCDFROOT =
ifneq ($(NETCDFROOT),)
  INCS_SER = -I$(NETCDFROOT)/include
  INCS_OMP = -I$(NETCDFROOT)/include
  INCS_MPI = -I$(NETCDFROOT)/include
  LIBS_SER = -L$(NETCDFROOT)/lib -lnetcdf -lnetcdff
  LIBS_OMP = -L$(NETCDFROOT)/lib -lnetcdf -lnetcdff
  LIBS_MPI = -L$(NETCDFROOT)/lib -lnetcdf -lnetcdff
  NCF_OBJS = nctablemd.o agioncmd.o swn_outnc.o
else
  INCS_SER =
  INCS_OMP =
  INCS_MPI =
  LIBS_SER =
  LIBS_OMP =
  LIBS_MPI =
  NCF_OBJS =
endif
O_DIR =
OUT = -o 
EXTO = o
MAKE = make
RM = rm -f
ifneq ($(NETCDFROOT),)
  swch = -unix -netcdf
else
  swch = -unix
endif
