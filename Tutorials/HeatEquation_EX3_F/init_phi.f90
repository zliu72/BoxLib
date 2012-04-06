module init_phi_module

  use multifab_module
  use ml_layout_module
  use define_bc_module
  use multifab_physbc_module
  use multifab_fill_ghost_module
!  use ml_restriction_module

  implicit none

  private

  public :: init_phi

contains
  
  subroutine init_phi(mla,phi,dx,prob_lo,the_bc_tower)

    type(ml_layout), intent(in   ) :: mla
    type(multifab) , intent(inout) :: phi(:)
    real(kind=dp_t), intent(in   ) :: dx(:)
    real(kind=dp_t), intent(in   ) :: prob_lo(mla%dim)
    type(bc_tower) , intent(in   ) :: the_bc_tower

    ! local variables
    integer :: lo(mla%dim), hi(mla%dim)
    integer :: nlevs, dm, ng, i, n

    real(kind=dp_t), pointer :: dp(:,:,:,:)

    ! set these here so we don't have to pass them into the subroutine
    ng = phi(1)%ng

    dm = mla%dim
    nlevs = mla%nlevel

    do n=1,nlevs

       do i=1,nboxes(phi(n))
          if ( multifab_remote(phi(n),i) ) cycle
          dp => dataptr(phi(n),i)
          lo = lwb(get_box(phi(n),i))
          hi = upb(get_box(phi(n),i))
          select case(dm)
          case (2)
             call init_phi_2d(dp(:,:,1,1), ng, lo, hi, prob_lo, dx(n))
          case (3)
             call init_phi_3d(dp(:,:,:,1), ng, lo, hi, prob_lo, dx(n))
          end select
       end do

       ! fill ghost cells
       ! this only fills periodic ghost cells and ghost cells for neighboring
       ! grids at the same level.  Physical boundary ghost cells are filled
       ! using multifab_physbc.  But this problem is periodic, so this
       ! call is sufficient.
       call multifab_fill_boundary(phi(n))
       
       ! physical domain boundary ghost cells
       call multifab_physbc(phi(n),1,1,1,the_bc_tower%bc_tower_array(n))
       
    end do

!    do n=nlevs,2,-1
!       call ml_cc_restriction(phi(n-1),phi(n),mla%mba%rr(n-1,:))
!    end do

    do n=2,nlevs
       call multifab_fill_ghost_cells(phi(n),phi(n-1),ng,mla%mba%rr(n-1,:), &
                                      the_bc_tower%bc_tower_array(n-1), &
                                      the_bc_tower%bc_tower_array(n), &
                                      1,1,1)
    end do

  end subroutine init_phi

  subroutine init_phi_2d(phi, ng, lo, hi, prob_lo, dx)

    integer          :: lo(2), hi(2), ng
    double precision :: phi(lo(1)-ng:,lo(2)-ng:)
    double precision :: prob_lo(2)
    double precision :: dx
 
    ! local varables
    integer          :: i,j
    double precision :: x,y,r2

    !$omp parallel do private(i,j,x,y,r2)
    do j=lo(2),hi(2)
       y = prob_lo(2) + (dble(j)+0.5d0) * dx
       do i=lo(1),hi(1)
          x = prob_lo(1) + (dble(i)+0.5d0) * dx

          r2 = ((x-0.5d0)**2 + (y-0.5d0)**2) / 0.01d0
          phi(i,j) = exp(-r2)

       end do
    end do
    !$omp end parallel do

    end subroutine init_phi_2d

    subroutine init_phi_3d(phi, ng, lo, hi, prob_lo, dx)

    integer          :: lo(3), hi(3), ng
    double precision :: phi(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:)
    double precision :: prob_lo(3)
    double precision :: dx
 
    ! local varables
    integer          :: i,j,k
    double precision :: x,y,z,r2

    !$omp parallel do private(i,j,k,x,y,z,r2)
    do k=lo(3),hi(3)
       z = prob_lo(3) + (dble(k)+0.5d0) * dx
       do j=lo(2),hi(2)
          y = prob_lo(2) + (dble(j)+0.5d0) * dx
          do i=lo(1),hi(1)
             x = prob_lo(1) + (dble(i)+0.5d0) * dx

             r2 = ((x-0.5d0)**2 + (y-0.5d0)**2 + (z-0.5d0)**2) / 0.01d0
             phi(i,j,k) = exp(-r2)

          end do
       end do
    end do
    !$omp end parallel do

  end subroutine init_phi_3d

end module init_phi_module