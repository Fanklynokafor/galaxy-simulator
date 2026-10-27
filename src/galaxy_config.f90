module galaxy_config
  use, intrinsic :: iso_fortran_env, only: error_unit
  use galaxy_kinds, only: dp, i4
  implicit none
  private

  public :: simulation_config, load_config

  type :: simulation_config
    integer(i4) :: n_particles = 160_i4
    integer(i4) :: steps = 1200_i4
    integer(i4) :: snapshot_stride = 20_i4
    real(dp) :: dt_myr = 0.5_dp
    real(dp) :: disk_mass = 5.0_dp
    real(dp) :: disk_scale_kpc = 3.0_dp
    real(dp) :: disk_outer_kpc = 12.0_dp
    real(dp) :: halo_mass = 45.0_dp
    real(dp) :: halo_scale_kpc = 8.0_dp
    real(dp) :: softening_kpc = 0.15_dp
    character(len=256) :: snapshots_file = 'snapshots.csv'
    character(len=256) :: energy_file = 'energy.csv'
  end type simulation_config

contains

  subroutine load_config(config, path)
    type(simulation_config), intent(out) :: config
    character(len=*), intent(in) :: path
    integer :: unit, io_status
    character(len=512) :: io_message

    integer(i4) :: n_particles, steps, snapshot_stride
    real(dp) :: dt_myr, disk_mass, disk_scale_kpc, disk_outer_kpc
    real(dp) :: halo_mass, halo_scale_kpc, softening_kpc
    character(len=256) :: snapshots_file, energy_file
    namelist /galaxy/ n_particles, steps, snapshot_stride, dt_myr, &
      disk_mass, disk_scale_kpc, disk_outer_kpc, halo_mass, &
      halo_scale_kpc, softening_kpc, snapshots_file, energy_file

    ! Start from defaults so an intentionally short namelist remains useful.
    n_particles = config%n_particles
    steps = config%steps
    snapshot_stride = config%snapshot_stride
    dt_myr = config%dt_myr
    disk_mass = config%disk_mass
    disk_scale_kpc = config%disk_scale_kpc
    disk_outer_kpc = config%disk_outer_kpc
    halo_mass = config%halo_mass
    halo_scale_kpc = config%halo_scale_kpc
    softening_kpc = config%softening_kpc
    snapshots_file = config%snapshots_file
    energy_file = config%energy_file

    open(newunit=unit, file=trim(path), status='old', action='read', &
      iostat=io_status, iomsg=io_message)
    if (io_status /= 0) then
      write(error_unit, '(a)') 'Could not open configuration file: '//trim(io_message)
      error stop 1
    end if
    read(unit, nml=galaxy, iostat=io_status, iomsg=io_message)
    close(unit)
    if (io_status /= 0) then
      write(error_unit, '(a)') 'Could not read &galaxy namelist: '//trim(io_message)
      error stop 1
    end if

    config%n_particles = n_particles
    config%steps = steps
    config%snapshot_stride = snapshot_stride
    config%dt_myr = dt_myr
    config%disk_mass = disk_mass
    config%disk_scale_kpc = disk_scale_kpc
    config%disk_outer_kpc = disk_outer_kpc
    config%halo_mass = halo_mass
    config%halo_scale_kpc = halo_scale_kpc
    config%softening_kpc = softening_kpc
    config%snapshots_file = snapshots_file
    config%energy_file = energy_file

    call validate_config(config)
  end subroutine load_config

  subroutine validate_config(config)
    type(simulation_config), intent(in) :: config

    if (config%n_particles < 2) error stop 'n_particles must be at least 2'
    if (config%steps < 1) error stop 'steps must be positive'
    if (config%snapshot_stride < 1) error stop 'snapshot_stride must be positive'
    if (config%dt_myr <= 0.0_dp) error stop 'dt_myr must be positive'
    if (config%disk_mass <= 0.0_dp) error stop 'disk_mass must be positive'
    if (config%disk_scale_kpc <= 0.0_dp) error stop 'disk_scale_kpc must be positive'
    if (config%disk_outer_kpc <= 0.0_dp) error stop 'disk_outer_kpc must be positive'
    if (config%halo_mass < 0.0_dp) error stop 'halo_mass cannot be negative'
    if (config%halo_scale_kpc <= 0.0_dp) error stop 'halo_scale_kpc must be positive'
    if (config%softening_kpc <= 0.0_dp) error stop 'softening_kpc must be positive'
    if (len_trim(config%snapshots_file) == 0) error stop 'snapshots_file cannot be empty'
    if (len_trim(config%energy_file) == 0) error stop 'energy_file cannot be empty'
  end subroutine validate_config
end module galaxy_config
