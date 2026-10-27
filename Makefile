FC = gfortran
FFLAGS ?= -O2 -std=f2008 -Wall -Wextra -Wimplicit-interface -fcheck=bounds
SRC = src/galaxy_kinds.f90 src/galaxy_config.f90 src/galaxy_dynamics.f90 src/galaxy_io.f90 src/main.f90
OBJ = $(SRC:.f90=.o)

.PHONY: all clean

all: galaxy_simulator

galaxy_simulator: $(OBJ)
	$(FC) $(FFLAGS) -o $@ $(OBJ)

src/galaxy_config.o: src/galaxy_kinds.o
src/galaxy_dynamics.o: src/galaxy_kinds.o src/galaxy_config.o
src/galaxy_io.o: src/galaxy_kinds.o src/galaxy_config.o src/galaxy_dynamics.o
src/main.o: src/galaxy_kinds.o src/galaxy_config.o src/galaxy_dynamics.o src/galaxy_io.o

%.o: %.f90
	$(FC) $(FFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) galaxy_simulator *.mod src/*.mod
