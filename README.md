# Galaxy Simulator

A small, self-contained galaxy dynamics model written in Fortran. It evolves a rotating stellar disk under the disk particles' mutual gravity and a fixed spherical dark matter halo. The model is intended for learning and experimentation; it is not a precision cosmology or galaxy-formation code.

## Model

- Positions are in kiloparsecs (kpc), time is in millions of years (Myr), and mass is in units of (10^{10}) solar masses.
- The disk is initialized as deterministic concentric rings with an exponential radial profile.
- Disk particles interact through Newtonian gravity with Plummer softening.
- A static Hernquist halo supplies an additional radial acceleration.
- A kick-drift-kick (leapfrog) integrator advances the system.
- `snapshots.csv` contains particle states. `energy.csv` tracks kinetic, disk potential, halo potential, and total energy.

The disk particle distribution is a finite, collisionless approximation. The halo is fixed, so it cannot respond to the disk. The initial circular speeds use an enclosed-mass approximation for the disk and the exact enclosed mass of the Hernquist halo; the exponential disk approximation is not an exact disk rotation curve. Choose a timestep small enough to resolve the shortest orbit and close encounters allowed by the softening length.

## Build

Requires a Fortran 2008 compiler; GNU Fortran is the default.

```sh
make
```

## Run

```sh
./galaxy_simulator
```

The program reads `galaxy.nml` from its current directory. A sample configuration is included. Override the file path as the first argument if needed:

```sh
./galaxy_simulator my_run.nml
```

The run replaces the configured output CSV files. The defaults are `snapshots.csv` and `energy.csv`. Use a plotting program of your choice to visualize the particle positions over time; the simulation and its source are entirely Fortran.

## Configuration

See `galaxy.nml` for all parameters. `n_particles` is kept modest by default because direct pairwise gravity costs O(N²) per force evaluation. Increasing it improves the smoothness of the disk but raises run time quadratically.

## Files

- `src/galaxy_kinds.f90` — numeric kinds and physical constants
- `src/galaxy_config.f90` — namelist input and validation
- `src/galaxy_dynamics.f90` — initialization, forces, integration, and diagnostics
- `src/galaxy_io.f90` — CSV output
- `src/main.f90` — program entry point
- `galaxy.nml` — sample run settings
- `Makefile` — compiler and build rules

## Notes for future me

- If the disk starts to heat up or the total energy drifts, first reduce `dt_myr`; then check whether the softening length is consistent with particle spacing.
- The halo stays fixed by design. A live halo would need its own particles and would change both the cost and the interpretation of the run.
- CSV output gets large quickly. Increase `snapshot_stride` before increasing the particle count for long runs.
- This is a Newtonian, isolated model. There is no gas, star formation, cosmological expansion, or relativistic effect hiding in the calculation.
