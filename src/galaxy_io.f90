module galaxy_io
  use, intrinsic :: iso_fortran_env, only: error_unit
  use galaxy_kinds, only: dp
  use galaxy_config, only: simulation_config
  use galaxy_dynamics, only: galaxy_state
  implicit none
  private

  public :: open_outputs, write_snapshot, write_energy, close_outputs

  integer, save :: snapshot_unit, energy_unit

contains

  subroutine open_outputs(config)
    type(simulation_config), intent(in) :: config
    integer :: io_status
    character(len=512) :: io_message

    open(newunit=snapshot_unit, file=trim(config%snapshots_file), status='replace', &
      action='write', iostat=io_status, iomsg=io_message)
    if (io_status /= 0) then
      write(error_unit, '(a)') 'Could not create snapshots file: '//trim(io_message)
      error stop 1
    end if
    open(newunit=energy_unit, file=trim(config%energy_file), status='replace', &
      action='write', iostat=io_status, iomsg=io_message)
    if (io_status /= 0) then
      write(error_unit, '(a)') 'Could not create energy file: '//trim(io_message)
      error stop 1
    end if

    write(snapshot_unit, '(a)') 'step,time_myr,id,x_kpc,y_kpc,z_kpc,vx_kpc_myr,vy_kpc_myr,vz_kpc_myr'
    write(energy_unit, '(a)') 'step,time_myr,kinetic,disk_potential,halo_potential,total_energy'
  end subroutine open_outputs

  subroutine write_snapshot(step, time_myr, state)
    integer, intent(in) :: step
    real(dp), intent(in) :: time_myr
    type(galaxy_state), intent(in) :: state
    integer :: particle

    do particle = 1, size(state%mass)
      write(snapshot_unit, '(i0,",",es20.12,",",i0,6(",",es20.12))') &
        step, time_myr, particle, state%position(:, particle), state%velocity(:, particle)
    end do
  end subroutine write_snapshot

  subroutine write_energy(step, time_myr, kinetic, disk_potential, halo_potential)
    integer, intent(in) :: step
    real(dp), intent(in) :: time_myr, kinetic, disk_potential, halo_potential

    write(energy_unit, '(i0,5(",",es20.12))') step, time_myr, kinetic, &
      disk_potential, halo_potential, kinetic + disk_potential + halo_potential
  end subroutine write_energy

  subroutine close_outputs()
    close(snapshot_unit)
    close(energy_unit)
  end subroutine close_outputs
end module galaxy_io
