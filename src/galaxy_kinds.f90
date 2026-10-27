module galaxy_kinds
  use, intrinsic :: iso_fortran_env, only: real64, int32
  implicit none
  private

  public :: dp, i4, gravitational_constant, pi

  integer, parameter :: dp = real64
  integer, parameter :: i4 = int32

  ! G in kpc^3 / (10^10 solar masses) / Myr^2.
  ! Future me: if you change the units, change this conversion and the
  ! documented velocity interpretation together. Unit bugs look like physics.
  real(dp), parameter :: gravitational_constant = 4.4985e-2_dp
  real(dp), parameter :: pi = acos(-1.0_dp)
end module galaxy_kinds
