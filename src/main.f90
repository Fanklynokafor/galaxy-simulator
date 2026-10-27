program galaxy_simulator
  use galaxy_kinds, only: dp
  use galaxy_config, only: simulation_config, load_config
  use galaxy_dynamics, only: galaxy_state, initialize_galaxy, &
    advance_leapfrog, diagnostics
  use galaxy_io, only: open_outputs, write_snapshot, write_energy, close_outputs
  implicit none

  type(simulation_config) :: config
  type(galaxy_state) :: state
  character(len=512) :: config_path
  integer :: step, argument_status
  real(dp) :: time_myr, kinetic, disk_potential, halo_potential

  config_path = 'galaxy.nml'
  if (command_argument_count() > 1) error stop 'Usage: galaxy_simulator [configuration.nml]'
  if (command_argument_count() == 1) then
    call get_command_argument(1, config_path, status=argument_status)
    if (argument_status /= 0) error stop 'Could not read configuration path argument'
  end if

  call load_config(config, trim(config_path))
  call initialize_galaxy(config, state)
  call open_outputs(config)

  time_myr = 0.0_dp
  call diagnostics(config, state, kinetic, disk_potential, halo_potential)
  call write_snapshot(0, time_myr, state)
  call write_energy(0, time_myr, kinetic, disk_potential, halo_potential)

  do step = 1, config%steps
    call advance_leapfrog(config, state, config%dt_myr)
    time_myr = real(step, dp) * config%dt_myr
    if (mod(step, config%snapshot_stride) == 0 .or. step == config%steps) then
      call write_snapshot(step, time_myr, state)
      call diagnostics(config, state, kinetic, disk_potential, halo_potential)
      call write_energy(step, time_myr, kinetic, disk_potential, halo_potential)
    end if
  end do

  call close_outputs()
  write(*, '(a,i0,a,f10.3,a)') 'Finished ', config%steps, &
    ' steps; simulated ', time_myr, ' Myr.'
  write(*, '(a,a)') 'Particle states: ', trim(config%snapshots_file)
  write(*, '(a,a)') 'Energy history:  ', trim(config%energy_file)
end program galaxy_simulator
