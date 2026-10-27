module galaxy_dynamics
  use galaxy_kinds, only: dp, gravitational_constant, pi
  use galaxy_config, only: simulation_config
  implicit none
  private

  public :: galaxy_state, initialize_galaxy, acceleration, advance_leapfrog, diagnostics

  type :: galaxy_state
    real(dp), allocatable :: position(:, :)  ! (coordinate, particle), kpc
    real(dp), allocatable :: velocity(:, :)  ! (coordinate, particle), kpc / Myr
    real(dp), allocatable :: mass(:)         ! 10^10 solar masses
  end type galaxy_state

contains

  subroutine initialize_galaxy(config, state)
    type(simulation_config), intent(in) :: config
    type(galaxy_state), intent(out) :: state
    integer :: i, ring, slot, ring_count
    real(dp) :: fraction, radius, theta, enclosed_disk, enclosed_halo
    real(dp) :: circular_speed, mass_fraction

    allocate(state%position(3, config%n_particles))
    allocate(state%velocity(3, config%n_particles))
    allocate(state%mass(config%n_particles))
    state%position = 0.0_dp
    state%velocity = 0.0_dp

    ! Equal particle masses keep the bookkeeping simple. Ring radii are chosen
    ! from the inverse CDF of an exponential disk, truncated at disk_outer_kpc.
    state%mass = config%disk_mass / real(config%n_particles, dp)
    do i = 1, config%n_particles
      ring = (i - 1) / max(1, int(sqrt(real(config%n_particles, dp))))
      ring_count = max(1, int(sqrt(real(config%n_particles, dp))))
      slot = mod(i - 1, ring_count)
      fraction = (real(ring, dp) + 0.5_dp) / &
        real(ceiling(real(config%n_particles, dp) / real(ring_count, dp)), dp)
      mass_fraction = fraction * (1.0_dp - &
        (1.0_dp + config%disk_outer_kpc / config%disk_scale_kpc) * &
        exp(-config%disk_outer_kpc / config%disk_scale_kpc))
      radius = exponential_disk_radius(mass_fraction, config%disk_scale_kpc)
      theta = 2.0_dp * pi * (real(slot, dp) / real(ring_count, dp) + &
        0.37_dp * real(ring, dp) / real(ring_count, dp))

      state%position(1, i) = radius * cos(theta)
      state%position(2, i) = radius * sin(theta)

      ! Future me: this enclosed-mass estimate gives a sensible first orbit,
      ! but it is not the exact rotation curve of a razor-thin exponential disk.
      enclosed_disk = config%disk_mass * &
        (1.0_dp - (1.0_dp + radius / config%disk_scale_kpc) * &
        exp(-radius / config%disk_scale_kpc))
      enclosed_halo = config%halo_mass * radius**2 / &
        (radius + config%halo_scale_kpc)**2
      circular_speed = sqrt(gravitational_constant * &
        max(enclosed_disk + enclosed_halo, 1.0e-12_dp) / max(radius, 1.0e-12_dp))
      state%velocity(1, i) = -circular_speed * sin(theta)
      state%velocity(2, i) = circular_speed * cos(theta)
    end do
  end subroutine initialize_galaxy

  pure function exponential_disk_radius(target_fraction, scale_length) result(radius)
    real(dp), intent(in) :: target_fraction, scale_length
    real(dp) :: radius, low, high, middle, enclosed
    integer :: iteration

    ! Invert 1 - (1+x) exp(-x) by bisection. A fixed iteration count makes
    ! initialization repeatable across runs and avoids a random-number seed.
    low = 0.0_dp
    high = 30.0_dp * scale_length
    do iteration = 1, 64
      middle = 0.5_dp * (low + high)
      enclosed = 1.0_dp - (1.0_dp + middle / scale_length) * &
        exp(-middle / scale_length)
      if (enclosed < target_fraction) then
        low = middle
      else
        high = middle
      end if
    end do
    radius = 0.5_dp * (low + high)
  end function exponential_disk_radius

  subroutine acceleration(config, state, result)
    type(simulation_config), intent(in) :: config
    type(galaxy_state), intent(in) :: state
    real(dp), intent(out) :: result(:, :)
    integer :: i, j, particle_count
    real(dp) :: dx, dy, dz, distance2, inverse_distance3, radius, halo_factor

    particle_count = size(state%mass)
    result = 0.0_dp
    do i = 1, particle_count - 1
      do j = i + 1, particle_count
        dx = state%position(1, j) - state%position(1, i)
        dy = state%position(2, j) - state%position(2, i)
        dz = state%position(3, j) - state%position(3, i)
        distance2 = dx*dx + dy*dy + dz*dz + config%softening_kpc**2
        inverse_distance3 = 1.0_dp / (distance2 * sqrt(distance2))
        result(:, i) = result(:, i) + gravitational_constant * state%mass(j) * &
          [dx, dy, dz] * inverse_distance3
        result(:, j) = result(:, j) - gravitational_constant * state%mass(i) * &
          [dx, dy, dz] * inverse_distance3
      end do
    end do

    ! A fixed Hernquist halo: a(r) = -G M r_vec / (r (r+a)^2).
    ! Future me: the r=0 branch matters even though the initialized disk avoids it.
    do i = 1, particle_count
      radius = sqrt(sum(state%position(:, i)**2))
      if (radius > 0.0_dp .and. config%halo_mass > 0.0_dp) then
        halo_factor = -gravitational_constant * config%halo_mass / &
          (radius * (radius + config%halo_scale_kpc)**2)
        result(:, i) = result(:, i) + halo_factor * state%position(:, i)
      end if
    end do
  end subroutine acceleration

  subroutine advance_leapfrog(config, state, dt)
    type(simulation_config), intent(in) :: config
    type(galaxy_state), intent(inout) :: state
    real(dp), intent(in) :: dt
    real(dp), allocatable :: accel(:, :)

    allocate(accel(3, size(state%mass)))
    call acceleration(config, state, accel)
    state%velocity = state%velocity + 0.5_dp * dt * accel
    state%position = state%position + dt * state%velocity
    call acceleration(config, state, accel)
    state%velocity = state%velocity + 0.5_dp * dt * accel
  end subroutine advance_leapfrog

  subroutine diagnostics(config, state, kinetic, disk_potential, halo_potential)
    type(simulation_config), intent(in) :: config
    type(galaxy_state), intent(in) :: state
    real(dp), intent(out) :: kinetic, disk_potential, halo_potential
    integer :: i, j
    real(dp) :: separation, radius

    kinetic = 0.5_dp * sum(state%mass * sum(state%velocity**2, dim=1))
    disk_potential = 0.0_dp
    do i = 1, size(state%mass) - 1
      do j = i + 1, size(state%mass)
        separation = sqrt(sum((state%position(:, i) - state%position(:, j))**2) + &
          config%softening_kpc**2)
        disk_potential = disk_potential - gravitational_constant * &
          state%mass(i) * state%mass(j) / separation
      end do
    end do

    halo_potential = 0.0_dp
    do i = 1, size(state%mass)
      radius = sqrt(sum(state%position(:, i)**2))
      halo_potential = halo_potential - gravitational_constant * config%halo_mass * &
        state%mass(i) / (radius + config%halo_scale_kpc)
    end do
  end subroutine diagnostics
end module galaxy_dynamics
