module cc_smoothers_module

  use bl_constants_module
  use stencil_module

  implicit none

  private dgtsl

contains

  subroutine gs_line_solve_1d(ss, uu, ff, mm, lo, ng)

    use tridiag_module, only : tridiag

    integer, intent(in) :: lo(:)
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in)    :: ff(lo(1):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:)
    real (kind = dp_t), intent(in)    :: ss(lo(1):,0:)
    integer            ,intent(in)    :: mm(lo(1):)

    real (kind = dp_t), allocatable :: a_ls(:), b_ls(:), c_ls(:), r_ls(:), u_ls(:)
    integer :: ilen, i, hi(size(lo))
    integer, parameter ::  XBC = 3

    hi = ubound(ff)

    ilen = hi(1)-lo(1)+1
    allocate(a_ls(0:hi(1)-lo(1)))
    allocate(b_ls(0:hi(1)-lo(1)))
    allocate(c_ls(0:hi(1)-lo(1)))
    allocate(r_ls(0:hi(1)-lo(1)))
    allocate(u_ls(0:hi(1)-lo(1)))

    do i = lo(1), hi(1)
      a_ls(i-lo(1)) = ss(i,2)
      b_ls(i-lo(1)) = ss(i,0)
      c_ls(i-lo(1)) = ss(i,1)
      r_ls(i-lo(1)) = ff(i)

      if ( hi(1) > lo(1) ) then
         if (bc_skewed(mm(i),1,+1)) then
            r_ls(i-lo(1)) = r_ls(i-lo(1)) - ss(i,XBC)*uu(i+2)
         else if (bc_skewed(mm(i),1,-1)) then
            r_ls(i-lo(1)) = r_ls(i-lo(1)) - ss(i,XBC)*uu(i-2)
         end if
      end if

    end do

    r_ls(0)           = r_ls(0)           - ss(lo(1),2) * uu(lo(1)-1)
    r_ls(hi(1)-lo(1)) = r_ls(hi(1)-lo(1)) - ss(hi(1),1) * uu(hi(1)+1)

    call tridiag(a_ls,b_ls,c_ls,r_ls,u_ls,ilen)
 
    do i = lo(1), hi(1)
       uu(i) = u_ls(i-lo(1))
    end do

  end subroutine gs_line_solve_1d

  subroutine gs_rb_smoother_1d(omega, ss, uu, ff, mm, lo, ng, n, skwd)
    use bl_prof_module
    integer, intent(in) :: ng
    integer, intent(in) :: lo(:)
    integer, intent(in) :: n
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(lo(1):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:)
    real (kind = dp_t), intent(in) :: ss(lo(1):,0:)
    integer            ,intent(in) :: mm(lo(1):)
    logical, intent(in), optional :: skwd
    integer :: i, hi(size(lo)), ioff
    integer, parameter ::  XBC = 3
    real (kind = dp_t) :: dd
    logical :: lskwd
    real(dp_t) :: lr(2)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "gs_rb_smoother_1d")

    lr = 0

    hi = ubound(ff)

    if (present(skwd) ) then
       lskwd = skwd
    else 
       lskwd = .false.
       if (bc_skewed(mm(lo(1)),1,+1)) lskwd = .true.
       if (bc_skewed(mm(hi(1)),1,-1)) lskwd = .true.
    end if

    !! assumption: ss(i,0) vanishes only for 1x1 problems
    if ( all(lo == hi) ) then
       i = lo(1)
       if ( mod(i,2) == n ) then
          if ( abs(ss(i,0)) .gt. 0.0_dp_t ) then
             dd = ss(i,0)*uu(i) &
                + ss(i,1)*uu(i+1) + ss(i,2)*uu(i-1) 
             uu(i) = uu(i) + omega/ss(i,0)*(ff(i) - dd)
          end if
       end if
       call destroy(bpt)
       return
    end if

    !! Assumption; bc_skewed is never true if hi==lo
    if ( lskwd ) then

       if (bc_skewed(mm(lo(1)),1,+1)) lr(1) = uu(lo(1)+2)
       if (bc_skewed(mm(hi(1)),1,-1)) lr(2) = uu(hi(1)-2)

       ioff = 0; if ( mod(lo(1), 2) /= n ) ioff = 1
       do i = lo(1) + ioff, hi(1), 2

             dd = ss(i,0)*uu(i) &
                  + ss(i,1) * uu(i+1) + ss(i,2) * uu(i-1)
             if ( i == lo(1) .or. i == hi(1)) then
                if (bc_skewed(mm(i),1,+1)) then
                   dd = dd + ss(i,XBC)*lr(1)
                end if
                if (bc_skewed(mm(i),1,-1)) then
                   dd = dd + ss(i,XBC)*lr(2)
                end if
             end if
             uu(i) = uu(i) + omega/ss(i,0)*(ff(i) - dd)
          end do

    else

       do i = lo(1), hi(1)
          if (abs(ss(i,0)) .gt. 0.0_dp_t) then
            dd = ss(i,0)*uu(i) &
               + ss(i,1)*uu(i+1) + ss(i,2)*uu(i-1) 
            uu(i) = uu(i) + omega/ss(i,0)*(ff(i) - dd)
          end if
       end do

    end if

    call destroy(bpt)

  end subroutine gs_rb_smoother_1d

  subroutine gs_rb_smoother_2d(omega, ss, uu, ff, mm, lo, ng, n, skwd)
    use bl_prof_module
    integer, intent(in) :: ng
    integer, intent(in) :: lo(:)
    integer, intent(in) :: n
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(lo(1):, lo(2):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:, lo(2)-ng:)
    real (kind = dp_t), intent(in) :: ss(lo(1):, lo(2):, 0:)
    integer            ,intent(in) :: mm(lo(1):,lo(2):)
    logical, intent(in), optional :: skwd
    integer :: j, i, hi(size(lo)), ioff
    integer, parameter ::  XBC = 5, YBC = 6
    real (kind = dp_t) :: dd
    logical :: lskwd
    real(dp_t) :: lr(lbound(ff,2):ubound(ff,2), 2)
    real(dp_t) :: tb(lbound(ff,1):ubound(ff,1), 2)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "gs_rb_smoother_2d")

    hi = ubound(ff)

    if (present(skwd) ) then
       lskwd = skwd
    else 
       lskwd = .false.
       do i = lo(1), hi(1)
          if (bc_skewed(mm(i,lo(2)),2,+1)) lskwd = .true.
          if (bc_skewed(mm(i,hi(2)),2,-1)) lskwd = .true.
       end do
       do j = lo(2), hi(2)
          if (bc_skewed(mm(lo(1),j),1,+1)) lskwd = .true.
          if (bc_skewed(mm(hi(1),j),1,-1)) lskwd = .true.
       end do
    end if

    !! assumption: ss(i,j,0) vanishes only for 1x1 problems
    if ( all(lo == hi) ) then
       i = lo(1); j = lo(2)
       if ( mod(i + j,2) == n ) then
          if ( abs(ss(i,j,0)) .gt. 0.0_dp_t ) then
             dd = ss(i,j,0)*uu(i,j) &
                  + ss(i,j,1)*uu(i+1,j) + ss(i,j,2)*uu(i-1,j) &
                  + ss(i,j,3)*uu(i,j+1) + ss(i,j,4)*uu(i,j-1)
             uu(i,j) = uu(i,j) + omega/ss(i,j,0)*(ff(i,j) - dd)
          end if
       end if
       call destroy(bpt)
       return
    end if
    !! Assumption; bc_skewed is never true if hi==lo

    if ( lskwd ) then

       do i = lo(1), hi(1)
          if (bc_skewed(mm(i,lo(2)),2,+1)) tb(i,1) = uu(i,lo(2)+2)
          if (bc_skewed(mm(i,hi(2)),2,-1)) tb(i,2) = uu(i,hi(2)-2)
       end do

       do j = lo(2), hi(2)
          if (bc_skewed(mm(lo(1),j),1,+1)) lr(j,1) = uu(lo(1)+2,j)
          if (bc_skewed(mm(hi(1),j),1,-1)) lr(j,2) = uu(hi(1)-2,j)
       end do

       do j = lo(2),hi(2)
          ioff = 0; if ( mod(lo(1) + j, 2) /= n ) ioff = 1
          do i = lo(1) + ioff, hi(1), 2

             dd = ss(i,j,0)*uu(i,j) &
                  + ss(i,j,1) * uu(i+1,j) + ss(i,j,2) * uu(i-1,j) &
                  + ss(i,j,3) * uu(i,j+1) + ss(i,j,4) * uu(i,j-1)
             if ( i == lo(1) .or. i == hi(1) .or. j == lo(2) .or. j == hi(2) ) then
                if (bc_skewed(mm(i,j),1,+1)) then
                   dd = dd + ss(i,j,XBC)*lr(j,1)
                end if
                if (bc_skewed(mm(i,j),1,-1)) then
                   dd = dd + ss(i,j,XBC)*lr(j,2)
                end if
                if (bc_skewed(mm(i,j),2,+1)) then
                   dd = dd + ss(i,j,YBC)*tb(i,1)
                end if
                if (bc_skewed(mm(i,j),2,-1)) then
                   dd = dd + ss(i,j,YBC)*tb(i,2)
                end if
             end if
             uu(i,j) = uu(i,j) + omega/ss(i,j,0)*(ff(i,j) - dd)
          end do
       end do
    else
       !
       ! USE THIS FOR GAUSS-SEIDEL
       !
       do j = lo(2),hi(2)
          ioff = 0; if ( mod(lo(1) + j, 2) /= n ) ioff = 1
          do i = lo(1) + ioff, hi(1), 2
             if (abs(ss(i,j,0)) .gt. 0.0_dp_t) then
               dd = ss(i,j,0)*uu(i,j) &
                    + ss(i,j,1) * uu(i+1,j) + ss(i,j,2) * uu(i-1,j) &
                    + ss(i,j,3) * uu(i,j+1) + ss(i,j,4) * uu(i,j-1)
               uu(i,j) = uu(i,j) + omega/ss(i,j,0)*(ff(i,j) - dd)
             end if
          end do
       end do

    end if

    call destroy(bpt)

  end subroutine gs_rb_smoother_2d

  subroutine gs_rb_smoother_3d(omega, ss, uu, ff, mm, lo, ng, n, skwd)
    use bl_prof_module
    integer, intent(in) :: ng
    integer, intent(in) :: lo(:)
    integer, intent(in) :: n
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(lo(1):,lo(2):,lo(3):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:)
    real (kind = dp_t), intent(in) :: ss(lo(1):, lo(2):, lo(3):, 0:)
    integer            ,intent(in) :: mm(lo(1):,lo(2):,lo(3):)
    logical, intent(in), optional :: skwd
    integer :: i, j, k, ioff
    integer :: hi(size(lo))
    integer, parameter ::  XBC = 7, YBC = 8, ZBC = 9
    logical :: lskwd
    real(dp_t), allocatable :: lr(:,:,:), tb(:,:,:), fb(:,:,:)
    real(dp_t) :: dd

    type(bl_prof_timer), save :: bpt

    call build(bpt, "gs_rb_smoother_3d")

    hi = ubound(ff)

    if ( all(lo == hi) ) then
       k = lo(3); j = lo(2); i = lo(1)
       if ( mod(i + j + k, 2) == n ) then
          if (abs(ss(i,j,k,0)) .gt. 0.0_dp_t) then
             dd = ss(i,j,k,0)*uu(i,j,k)
             dd = dd + ss(i,j,k,1)*uu(i+1,j,k) + ss(i,j,k,2)*uu(i-1,j,k)
             dd = dd + ss(i,j,k,3)*uu(i,j+1,k) + ss(i,j,k,4)*uu(i,j-1,k)
             dd = dd + ss(i,j,k,5)*uu(i,j,k+1) + ss(i,j,k,6)*uu(i,j,k-1)
             uu(i,j,k) = uu(i,j,k) + omega/ss(i,j,k,0)*(ff(i,j,k) - dd)
          end if
       end if
       call destroy(bpt)
       return
    end if

    if ( present(skwd) ) then
       lskwd = skwd
    else
       lskwd = .false.
       do k = lo(3), hi(3)
          do j = lo(2), hi(2)
             if ( bc_skewed(mm(lo(1),j,k),1,+1) .or. bc_skewed(mm(hi(1),j,k),1,-1) ) then
                lskwd = .true.
                goto 1234
             end if
          end do
       end do
       do k = lo(3), hi(3)
          do i = lo(1), hi(1)
             if ( bc_skewed(mm(i,lo(2),k),2,+1) .or. bc_skewed(mm(i,hi(2),k),2,-1) ) then
                lskwd = .true.
                goto 1234
             end if
          end do
       end do
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             if ( bc_skewed(mm(i,j,lo(3)),3,+1) .or. bc_skewed(mm(i,j,hi(3)),3,-1) ) then
                lskwd = .true.
                goto 1234
             end if
          end do
       end do
    end if

1234 if ( lskwd ) then

       allocate(lr(lbound(ff,2):ubound(ff,2), lbound(ff,3):ubound(ff,3), 2))
       allocate(tb(lbound(ff,1):ubound(ff,1), lbound(ff,3):ubound(ff,3), 2))
       allocate(fb(lbound(ff,1):ubound(ff,1), lbound(ff,2):ubound(ff,2), 2))

       do k = lo(3), hi(3)
          do i = lo(1), hi(1)
             if (bc_skewed(mm(i,lo(2),k),2,+1)) tb(i,k,1) = uu(i,lo(2)+2,k)
             if (bc_skewed(mm(i,hi(2),k),2,-1)) tb(i,k,2) = uu(i,hi(2)-2,k)
          end do
       end do

       do k = lo(3), hi(3)
          do j = lo(2), hi(2)
             if (bc_skewed(mm(lo(1),j,k),1,+1)) lr(j,k,1) = uu(lo(1)+2,j,k)
             if (bc_skewed(mm(hi(1),j,k),1,-1)) lr(j,k,2) = uu(hi(1)-2,j,k)
          end do
       end do

       do j = lo(2), hi(2) 
          do i = lo(1), hi(1)
             if (bc_skewed(mm(i,j,lo(3)),3,+1)) fb(i,j,1) = uu(i,j,lo(3)+2)
             if (bc_skewed(mm(i,j,hi(3)),3,-1)) fb(i,j,2) = uu(i,j,hi(3)-2)
          end do
       end do

       !$OMP PARALLEL DO PRIVATE(k,j,i,ioff,dd) IF((hi(3)-lo(3)).ge.3)
       do k = lo(3), hi(3)
          do j = lo(2), hi(2)
             ioff = 0; if ( mod(lo(1) + j + k, 2) /= n ) ioff = 1
             do i = lo(1)+ioff, hi(1), 2

                dd = ss(i,j,k,0)*uu(i,j,k) + &
                     ss(i,j,k,1)*uu(i+1,j,k) + ss(i,j,k,2)*uu(i-1,j,k) + &
                     ss(i,j,k,3)*uu(i,j+1,k) + ss(i,j,k,4)*uu(i,j-1,k) + &
                     ss(i,j,k,5)*uu(i,j,k+1) + ss(i,j,k,6)*uu(i,j,k-1)

                if ( i == lo(1)) then
                   if ( bc_skewed(mm(i,j,k),1,+1) ) dd = dd + ss(i,j,k,XBC)*lr(j,k,1)
                end if
                if ( i == hi(1)) then
                   if ( bc_skewed(mm(i,j,k),1,-1) ) dd = dd + ss(i,j,k,XBC)*lr(j,k,2)
                end if
                if ( j == lo(2)) then
                   if ( bc_skewed(mm(i,j,k),2,+1) ) dd = dd + ss(i,j,k,YBC)*tb(i,k,1)
                end if
                if ( j == hi(2) ) then
                   if ( bc_skewed(mm(i,j,k),2,-1) ) dd = dd + ss(i,j,k,YBC)*tb(i,k,2)
                end if
                if ( k == lo(3)) then
                   if ( bc_skewed(mm(i,j,k),3,+1) ) dd = dd + ss(i,j,k,ZBC)*fb(i,j,1)
                end if
                if ( k == hi(3) ) then
                   if ( bc_skewed(mm(i,j,k),3,-1) ) dd = dd + ss(i,j,k,ZBC)*fb(i,j,2)
                end if

                uu(i,j,k) = uu(i,j,k) + omega/ss(i,j,k,0)*(ff(i,j,k) - dd)
             end do
          end do
       end do
       !$OMP END PARALLEL DO

       deallocate(lr,tb,fb)
    else
       !
       ! USE THIS FOR GAUSS-SEIDEL
       !
       !$OMP PARALLEL DO PRIVATE(k,j,i,ioff,dd) IF((hi(3)-lo(3)).ge.3)
       do k = lo(3), hi(3)
          do j = lo(2), hi(2)
             ioff = 0; if ( mod (lo(1) + j + k, 2) /= n ) ioff = 1
             do i = lo(1)+ioff, hi(1), 2
                  dd = ss(i,j,k,0)*uu(i,j,k) + &
                       ss(i,j,k,1)*uu(i+1,j,k) + ss(i,j,k,2)*uu(i-1,j,k) + &
                       ss(i,j,k,3)*uu(i,j+1,k) + ss(i,j,k,4)*uu(i,j-1,k) + &
                       ss(i,j,k,5)*uu(i,j,k+1) + ss(i,j,k,6)*uu(i,j,k-1)

                  uu(i,j,k) = uu(i,j,k) + omega/ss(i,j,k,0)*(ff(i,j,k) - dd)
             end do
          end do
       end do
       !$OMP END PARALLEL DO

    end if

    call destroy(bpt)

  end subroutine gs_rb_smoother_3d

  subroutine minion_smoother_2d(omega, ss, uu, ff, lo, ng, n, is_cross)
    use bl_prof_module
    integer           , intent(in) :: ng, n
    integer           , intent(in) :: lo(:)
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(lo(1):, lo(2):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:, lo(2)-ng:)
    real (kind = dp_t), intent(in) :: ss(lo(1):, lo(2):, 0:)
    logical            ,intent(in) :: is_cross

    integer            :: i, j, hi(size(lo)), ioff
    real (kind = dp_t) :: dd

    type(bl_prof_timer), save :: bpt

    call build(bpt, "minion_smoother_2d")

    hi = ubound(ff)

    if (is_cross) then

       do j = lo(2),hi(2)
          ioff = 0; if ( mod(lo(1) + j, 2) /= n ) ioff = 1
          do i = lo(1) + ioff, hi(1), 2
             if (abs(ss(i,j,0)) .gt. 0.0_dp_t) then
               dd =   ss(i,j,0) * uu(i,j) &
                    + ss(i,j,1) * uu(i-2,j) + ss(i,j,2) * uu(i-1,j) &
                    + ss(i,j,3) * uu(i+1,j) + ss(i,j,4) * uu(i+2,j) &
                    + ss(i,j,5) * uu(i,j-2) + ss(i,j,6) * uu(i,j-1) &
                    + ss(i,j,7) * uu(i,j+1) + ss(i,j,8) * uu(i,j+2)
               uu(i,j) = uu(i,j) + (omega/ss(i,j,0)) * (ff(i,j) - dd)
             end if
          end do
       end do

    else

       do j = lo(2),hi(2)
          do i = lo(1), hi(1)
             if (abs(ss(i,j,0)) .gt. 0.0_dp_t) then
               dd =   ss(i,j, 0) * uu(i,j) &
                    + ss(i,j, 1) * uu(i-2,j-2) + ss(i,j, 2) * uu(i-1,j-2) & ! AT J-2
                    + ss(i,j, 3) * uu(i  ,j-2) + ss(i,j, 4) * uu(i+1,j-2) & ! AT J-2
                    + ss(i,j, 5) * uu(i+2,j-2)                            & ! AT J-2
                    + ss(i,j, 6) * uu(i-2,j-1) + ss(i,j, 7) * uu(i-1,j-1) & ! AT J-1
                    + ss(i,j, 8) * uu(i  ,j-1) + ss(i,j, 9) * uu(i+1,j-1) & ! AT J-1
                    + ss(i,j,10) * uu(i+2,j-1)                            & ! AT J-1
                    + ss(i,j,11) * uu(i-2,j  ) + ss(i,j,12) * uu(i-1,j  ) & ! AT J
                    + ss(i,j,13) * uu(i+1,j  ) + ss(i,j,14) * uu(i+2,j  ) & ! AT J
                    + ss(i,j,15) * uu(i-2,j+1) + ss(i,j,16) * uu(i-1,j+1) & ! AT J+1
                    + ss(i,j,17) * uu(i  ,j+1) + ss(i,j,18) * uu(i+1,j+1) & ! AT J+1
                    + ss(i,j,19) * uu(i+2,j+1)                            & ! AT J+1
                    + ss(i,j,20) * uu(i-2,j+2) + ss(i,j,21) * uu(i-1,j+2) & ! AT J+2
                    + ss(i,j,22) * uu(i  ,j+2) + ss(i,j,23) * uu(i+1,j+2) & ! AT J+2
                    + ss(i,j,24) * uu(i+2,j+2)                              ! AT J+2

               uu(i,j) = uu(i,j) + (omega/ss(i,j,0)) * (ff(i,j) - dd)

             end if
          end do
       end do

    end if

    call destroy(bpt)

  end subroutine minion_smoother_2d

  subroutine minion_smoother_3d(omega, ss, uu, ff, lo, ng, n, is_cross)
    use bl_prof_module
    integer           , intent(in   ) :: ng, n
    integer           , intent(in   ) :: lo(:)
    real (kind = dp_t), intent(in   ) :: omega
    real (kind = dp_t), intent(in   ) :: ff(lo(1):, lo(2):, lo(3):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:, lo(2)-ng:,lo(3)-ng:)
    real (kind = dp_t), intent(in   ) :: ss(lo(1):, lo(2):, lo(3):, 0:)
    logical            ,intent(in   ) :: is_cross

    integer            :: i, j, k, hi(size(lo))
    real (kind = dp_t) :: dd

    type(bl_prof_timer), save :: bpt

    call build(bpt, "minion_smoother_3d")

    hi = ubound(ff)

    if (is_cross) then

       do k = lo(3),hi(3)
       do j = lo(2),hi(2)
          do i = lo(1), hi(1)
             if (abs(ss(i,j,k,0)) .gt. 0.0_dp_t) then
               dd =   ss(i,j,k, 0) * uu(i,j,k) &
                    + ss(i,j,k, 1) * uu(i-2,j,k) + ss(i,j,k, 2) * uu(i-1,j,k) &
                    + ss(i,j,k, 3) * uu(i+1,j,k) + ss(i,j,k, 4) * uu(i+2,j,k) &
                    + ss(i,j,k, 5) * uu(i,j-2,k) + ss(i,j,k, 6) * uu(i,j-1,k) &
                    + ss(i,j,k, 7) * uu(i,j+1,k) + ss(i,j,k, 8) * uu(i,j+2,k) &
                    + ss(i,j,k, 9) * uu(i,j,k-2) + ss(i,j,k,10) * uu(i,j,k-1) &
                    + ss(i,j,k,11) * uu(i,j,k+1) + ss(i,j,k,12) * uu(i,j,k+2)
               uu(i,j,k) = uu(i,j,k) + (omega/ss(i,j,k,0)) * (ff(i,j,k) - dd)
             end if
          end do
       end do
       end do

    else

       call bl_error('3d minion full smoother not yet implemented')

    end if

    call destroy(bpt)

  end subroutine minion_smoother_3d

  subroutine gs_lex_smoother_1d(omega, ss, uu, ff, ng, skwd)
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in)    :: omega
    real (kind = dp_t), intent(in)    :: ff(:)
    real (kind = dp_t), intent(inout) :: uu(1-ng:)
    real (kind = dp_t), intent(in)    :: ss(:,0:)
    logical, intent(in), optional :: skwd
    real (kind = dp_t) :: dd
    integer :: i
    logical :: lskwd
    lskwd = .true.; if ( present(skwd) ) lskwd = skwd

    do i = 1, size(ff,dim=1)
       dd = ss(i,0)*uu(i) + ss(i,1)*uu(i+1) + ss(i,2)*uu(i-1)
       uu(i) = uu(i) + omega/ss(i,0)*(ff(i) - dd)
    end do

  end subroutine gs_lex_smoother_1d

  subroutine gs_lex_smoother_2d(omega, ss, uu, ff, ng, skwd)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(:, :)
    real (kind = dp_t), intent(inout) :: uu(1-ng:, 1-ng:)
    real (kind = dp_t), intent(in) :: ss(:, :, 0:)
    logical, intent(in), optional :: skwd
    integer :: j, i
    real (kind = dp_t) :: dd
    logical :: lskwd

    type(bl_prof_timer), save :: bpt

    call build(bpt, "gs_lex_smoother_2d")

    lskwd = .true.; if ( present(skwd) ) lskwd = skwd

    do j = 1, size(ff,dim=2)
       do i = 1, size(ff, dim=1)
          dd = &
               + ss(i,j,0)*uu(i  ,j  ) &
               + ss(i,j,1)*uu(i+1,j  ) &
               + ss(i,j,2)*uu(i-1,j  ) &
               + ss(i,j,3)*uu(i  ,j+1) &
               + ss(i,j,4)*uu(i  ,j-1)
          uu(i,j) = uu(i,j) + omega/ss(i,j,0)*(ff(i,j) - dd)
       end do
    end do

    call destroy(bpt)
  end subroutine gs_lex_smoother_2d

  subroutine gs_lex_smoother_3d(omega, ss, uu, ff, ng, skwd)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(:,:,:)
    real (kind = dp_t), intent(inout) :: uu(1-ng:,1-ng:,1-ng:)
    real (kind = dp_t), intent(in) :: ss(:,:,:,0:)
    logical, intent(in), optional :: skwd
    integer :: i, j, k
    real (kind = dp_t) :: dd
    logical :: lskwd

    type(bl_prof_timer), save :: bpt

    call build(bpt, "gs_lex_smoother_3d")

    lskwd = .true.; if ( present(skwd) ) lskwd = skwd

    do k = 1, size(ff,dim=3)
       do j = 1, size(ff,dim=2)
          do i = 1, size(ff,dim=1)
             dd = &
                  + ss(i,j,k, 0)*uu(  i,j  ,k  ) &
                  + ss(i,j,k, 1)*uu(i+1,j  ,k  ) &
                  + ss(i,j,k, 2)*uu(i-1,j  ,k  ) &
                  + ss(i,j,k, 3)*uu(i  ,j+1,k  ) &
                  + ss(i,j,k, 4)*uu(i  ,j-1,k  ) &
                  + ss(i,j,k, 5)*uu(i  ,j  ,k-1) &
                  + ss(i,j,k, 6)*uu(i  ,j  ,k+1) 
             uu(i,j,k) = uu(i,j,k) + omega/ss(i,j,k,0)*(ff(i,j,k) - dd)
          end do
       end do
    end do

    call destroy(bpt)

  end subroutine gs_lex_smoother_3d

  subroutine gs_lex_dense_smoother_1d(omega, ss, uu, ff, ng, skwd)
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in)    :: omega
    real (kind = dp_t), intent(in)    :: ff(:)
    real (kind = dp_t), intent(inout) :: uu(1-ng:)
    real (kind = dp_t), intent(in)    :: ss(:,0:)
    logical, intent(in), optional :: skwd
    real (kind = dp_t) :: dd
    integer :: i
    logical :: lskwd
    lskwd = .true.; if ( present(skwd) ) lskwd = skwd

    do i = 1, size(ff,dim=1)
       dd = ss(i,0)*uu(i) + ss(i,1)*uu(i+1) + ss(i,2)*uu(i-1)
       uu(i) = uu(i) + omega/ss(i,0)*(ff(i) - dd)
    end do


  end subroutine gs_lex_dense_smoother_1d

  subroutine gs_lex_dense_smoother_2d(omega, ss, uu, ff, ng, skwd)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(:, :)
    real (kind = dp_t), intent(inout) :: uu(1-ng:, 1-ng:)
    real (kind = dp_t), intent(in) :: ss(:, :, 0:)
    logical, intent(in), optional :: skwd
    integer :: j, i
    real (kind = dp_t) :: dd
    logical :: lskwd

    type(bl_prof_timer), save :: bpt

    call build(bpt, "gs_lex_dense_smoother_2d")

    lskwd = .true.; if ( present(skwd) ) lskwd = skwd

    do j = 1, size(ff,dim=2)
       do i = 1, size(ff, dim=1)
          dd = &
               + ss(i,j,1)*uu(i-1,j-1) &
               + ss(i,j,2)*uu(i  ,j-1) &
               + ss(i,j,3)*uu(i+1,j-1) &
               
               + ss(i,j,4)*uu(i-1,j  ) &
               + ss(i,j,0)*uu(i  ,j  ) &
               + ss(i,j,5)*uu(i+1,j  ) &
               
               + ss(i,j,6)*uu(i-1,j+1) &
               + ss(i,j,7)*uu(i  ,j+1) &
               + ss(i,j,8)*uu(i+1,j+1)
          uu(i,j) = uu(i,j) + omega/ss(i,j,0)*(ff(i,j) - dd)
       end do
    end do

    call destroy(bpt)

  end subroutine gs_lex_dense_smoother_2d

  subroutine gs_lex_dense_smoother_3d(omega, ss, uu, ff, ng, skwd)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ff(:,:,:)
    real (kind = dp_t), intent(inout) :: uu(1-ng:,1-ng:,1-ng:)
    real (kind = dp_t), intent(in) :: ss(:,:,:,0:)
    logical, intent(in), optional :: skwd
    integer :: i, j, k
    real (kind = dp_t) :: dd
    logical :: lskwd

    type(bl_prof_timer), save :: bpt

    call build(bpt, "gs_lex_dense_smoother_3d")

    lskwd = .true.; if ( present(skwd) ) lskwd = skwd

    do k = 1, size(ff,dim=3)
       do j = 1, size(ff,dim=2)
          do i = 1, size(ff,dim=1)
             dd = &
                  + ss(i,j,k, 0)*uu(i  ,j  ,k  ) &
                  + ss(i,j,k, 1)*uu(i-1,j-1,k-1) &
                  + ss(i,j,k, 2)*uu(i  ,j-1,k-1) &
                  + ss(i,j,k, 3)*uu(i+1,j-1,k-1) &
                  + ss(i,j,k, 4)*uu(i-1,j  ,k-1) &
                  + ss(i,j,k, 5)*uu(i  ,j  ,k-1) &
                  + ss(i,j,k, 6)*uu(i+1,j  ,k-1) &
                  + ss(i,j,k, 7)*uu(i-1,j+1,k-1) &
                  + ss(i,j,k, 8)*uu(i  ,j+1,k-1) &
                  + ss(i,j,k, 9)*uu(i+1,j+1,k-1) &
                  
                  + ss(i,j,k,10)*uu(i-1,j-1,k  ) &
                  + ss(i,j,k,11)*uu(i  ,j-1,k  ) &
                  + ss(i,j,k,12)*uu(i+1,j-1,k  ) &
                  + ss(i,j,k,13)*uu(i-1,j  ,k  ) &
                  + ss(i,j,k, 0)*uu(i  ,j  ,k  ) &
                  + ss(i,j,k,14)*uu(i+1,j  ,k  ) &
                  + ss(i,j,k,15)*uu(i  ,j+1,k  ) &
                  + ss(i,j,k,16)*uu(i-1,j+1,k  ) &
                  + ss(i,j,k,17)*uu(i+1,j+1,k  ) &
                  
                  + ss(i,j,k,18)*uu(i-1,j-1,k+1) &
                  + ss(i,j,k,19)*uu(i  ,j-1,k+1) &
                  + ss(i,j,k,20)*uu(i+1,j-1,k+1) &
                  + ss(i,j,k,21)*uu(i-1,j  ,k+1) &
                  + ss(i,j,k,22)*uu(i  ,j  ,k+1) &
                  + ss(i,j,k,23)*uu(i+1,j  ,k+1) &
                  + ss(i,j,k,24)*uu(i-1,j+1,k+1) &
                  + ss(i,j,k,25)*uu(i  ,j+1,k+1) &
                  + ss(i,j,k,26)*uu(i+1,j+1,k+1) 

             uu(i,j,k) = uu(i,j,k) + omega/ss(i,j,k,0)*(ff(i,j,k) - dd)
          end do
       end do
    end do

    call destroy(bpt)

  end subroutine gs_lex_dense_smoother_3d

  subroutine jac_smoother_1d(omega, ss, uu, ff, mm, ng)
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) ::  omega
    real (kind = dp_t), intent(in) ::  ss(:,0:)
    real (kind = dp_t), intent(in) ::  ff(:)
    integer           , intent(in) ::  mm(:)
    real (kind = dp_t), intent(inout) ::  uu(1-ng:)
    real (kind = dp_t):: wrk(size(ff,1))
    integer :: nx
    integer :: i
    real (kind = dp_t) :: dd
    integer, parameter ::  XBC = 3

    nx = size(ff,dim=1)
    do i = 1, nx
       dd = + ss(i,1)*uu(i+1) + ss(i,2)*uu(i-1) 
       if ( nx > 1 ) then
          if ( bc_skewed(mm(i),1,+1) ) then
             dd = dd + ss(i,XBC)*uu(i+2)
          else if ( bc_skewed(mm(i),1,-1) ) then
             dd = dd + ss(i,XBC)*uu(i-2)
          end if
       end if
       wrk(i) = ff(i) - dd
    end do
    do i = 1, nx
       uu(i) = uu(i) + omega*(wrk(i)/ss(i,0)-uu(i))
    end do

  end subroutine jac_smoother_1d

  subroutine jac_dense_smoother_1d(omega, ss, uu, ff, ng)
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) ::  omega
    real (kind = dp_t), intent(in) ::  ss(:,:)
    real (kind = dp_t), intent(in) ::  ff(:)
    real (kind = dp_t), intent(inout) ::  uu(1-ng:)
    real (kind = dp_t):: wrk(size(ff,1))
    integer :: nx, i

    nx = size(ff,dim=1)
    do i = 1, nx
       wrk(i) = ( ff(i) &
            - ss(i,1)*uu(i+1) - ss(i,3)*uu(i-1) &
            )
    end do
    do i = 1, nx
       uu(i) = uu(i) + omega*(wrk(i)/ss(i,2)-uu(i))
    end do

  end subroutine jac_dense_smoother_1d

  subroutine jac_smoother_2d(omega, ss, uu, ff, mm, ng)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) ::  omega
    real (kind = dp_t), intent(in) ::  ss(:,:,0:)
    real (kind = dp_t), intent(in) ::  ff(:,:)
    integer           , intent(in) ::  mm(:,:)
    real (kind = dp_t), intent(inout) ::  uu(1-ng:,1-ng:)
    real (kind = dp_t) :: wrk(size(ff,1),size(ff,2))
    integer :: nx, ny
    integer :: i, j
    real (kind = dp_t) :: dd
    integer, parameter ::  XBC = 5, YBC = 6

    type(bl_prof_timer), save :: bpt

    call build(bpt, "jac_smoother_2d")

    nx = size(ff,dim=1)
    ny = size(ff,dim=2)

    do j = 1, ny
       do i = 1, nx
          dd =    + ss(i,j,1) * uu(i+1,j) + ss(i,j,2) * uu(i-1,j)
          dd = dd + ss(i,j,3) * uu(i,j+1) + ss(i,j,4) * uu(i,j-1)
          if ( nx > 1 ) then
             if (bc_skewed(mm(i,j),1,+1)) then
                dd = dd + ss(i,j,XBC)*uu(i+2,j)
             else if (bc_skewed(mm(i,j),1,-1)) then
                dd = dd + ss(i,j,XBC)*uu(i-2,j)
             end if
          end if
          if ( ny > 1 ) then
             if (bc_skewed(mm(i,j),2,+1)) then
                dd = dd + ss(i,j,YBC)*uu(i,j+2)
             else if (bc_skewed(mm(i,j),2,-1)) then
                dd = dd + ss(i,j,YBC)*uu(i,j-2)
             end if
          end if
          wrk(i,j) = ff(i,j) - dd
       end do
    end do

    do j = 1, ny
       do i = 1, nx
          uu(i,j) = uu(i,j) + omega*(wrk(i,j)/ss(i,j,0)-uu(i,j))
       end do
    end do

    call destroy(bpt)

  end subroutine jac_smoother_2d

  subroutine jac_dense_smoother_2d(omega, ss, uu, ff, ng)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ss(:,:,0:)
    real (kind = dp_t), intent(in) :: ff(:,:)
    real (kind = dp_t), intent(inout) :: uu(1-ng:,1-ng:)
    real (kind = dp_t) :: wrk(size(ff,1),size(ff,2))
    integer :: i, j
    integer :: nx, ny

    type(bl_prof_timer), save :: bpt

    call build(bpt, "jac_dense_smoother_2d")

    nx=size(ss,dim=1)
    ny=size(ss,dim=2)

    do j = 1, ny
       do i = 1, nx
          wrk(i,j) = ff(i,j) - (&
               + ss(i,j,1)*uu(i-1,j-1) &
               + ss(i,j,2)*uu(i  ,j-1) &
               + ss(i,j,3)*uu(i+1,j-1) &
               
               + ss(i,j,4)*uu(i-1,j  ) &
               + ss(i,j,5)*uu(i+1,j  ) &
               
               + ss(i,j,6)*uu(i-1,j+1) &
               + ss(i,j,7)*uu(i  ,j+1) &
               + ss(i,j,8)*uu(i+1,j+1) &
               )
       end do
    end do

    do j = 1, ny
       do i = 1, nx
          uu(i,j) = uu(i,j) + omega*(wrk(i,j)/ss(i,j,0)-uu(i,j))
       end do
    end do

    call destroy(bpt)

  end subroutine jac_dense_smoother_2d

  subroutine jac_smoother_3d(omega, ss, uu, ff, mm, ng)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ss(:,:,:,0:)
    real (kind = dp_t), intent(in) :: ff(:,:,:)
    integer           , intent(in) :: mm(:,:,:)
    real (kind = dp_t), intent(inout) :: uu(1-ng:,1-ng:,1-ng:)
    real (kind = dp_t), allocatable :: wrk(:,:,:)
    real (kind = dp_t) :: dd
    integer :: nx, ny, nz
    integer :: i, j, k
    integer, parameter ::  XBC = 7, YBC = 8, ZBC = 9

    type(bl_prof_timer), save :: bpt

    call build(bpt, "jac_smoother_3d")

    nx = size(ff,dim=1)
    ny = size(ff,dim=2)
    nz = size(ff,dim=3)

    allocate(wrk(nx,ny,nz))

    !$OMP PARALLEL DO PRIVATE(j,i,k,dd) IF(nz.ge.4)
    do k = 1, nz
       do j = 1, ny
          do i = 1, nx
             dd = ss(i,j,k,1)*uu(i+1,j,k) + ss(i,j,k,2)*uu(i-1,j,k) + &
                  ss(i,j,k,3)*uu(i,j+1,k) + ss(i,j,k,4)*uu(i,j-1,k) + &
                  ss(i,j,k,5)*uu(i,j,k+1) + ss(i,j,k,6)*uu(i,j,k-1)

             if ( nx > 1 ) then
                if (bc_skewed(mm(i,j,k),1,+1)) then
                   dd = dd + ss(i,j,k,XBC)*uu(i+2,j,k)
                else if (bc_skewed(mm(i,j,k),1,-1)) then
                   dd = dd + ss(i,j,k,XBC)*uu(i-2,j,k)
                end if
             end if

             if ( ny > 1 ) then
                if (bc_skewed(mm(i,j,k),2,+1)) then
                   dd = dd + ss(i,j,k,YBC)*uu(i,j+2,k)
                else if (bc_skewed(mm(i,j,k),2,-1)) then
                   dd = dd + ss(i,j,k,YBC)*uu(i,j-2,k)
                end if
             end if

             if ( nz > 1 ) then
                if (bc_skewed(mm(i,j,k),3,+1)) then
                   dd = dd + ss(i,j,k,ZBC)*uu(i,j,k+2)
                else if (bc_skewed(mm(i,j,k),3,-1)) then
                   dd = dd + ss(i,j,k,ZBC)*uu(i,j,k-2)
                end if
             end if
             wrk(i,j,k) = ff(i,j,k) - dd
          end do
       end do
    end do
    !$OMP END PARALLEL DO

    !$OMP PARALLEL DO PRIVATE(j,i,k) IF(nz.ge.4)
    do k = 1, nz
       do j = 1, ny
          do i = 1, nx
             uu(i,j,k) = uu(i,j,k) + omega*(wrk(i,j,k)/ss(i,j,k,0) - uu(i,j,k))
          end do
       end do
    end do
    !$OMP END PARALLEL DO

    call destroy(bpt)

  end subroutine jac_smoother_3d

  subroutine jac_dense_smoother_3d(omega, ss, uu, ff, ng)
    use bl_prof_module
    integer, intent(in) :: ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ss(:,:,:,0:)
    real (kind = dp_t), intent(in) :: ff(:,:,:)
    real (kind = dp_t), intent(inout) :: uu(1-ng:,1-ng:,1-ng:)
    real (kind = dp_t), allocatable :: wrk(:,:,:)
    integer :: nx, ny, nz
    integer :: i, j, k

    type(bl_prof_timer), save :: bpt

    call build(bpt, "jac_dense_smoother_3d")

    nx = size(ff,dim=1)
    ny = size(ff,dim=2)
    nz = size(ff,dim=3)

    allocate(wrk(nx,ny,nz))

    !$OMP PARALLEL DO PRIVATE(j,i,k) IF(nz.ge.4)
    do k = 1, nz
       do j = 1, ny
          do i = 1, nx
             wrk(i,j,k) = ff(i,j,k) - ( &
                  + ss(i,j,k, 0)*uu(i  ,j  ,k)  &
                  + ss(i,j,k, 1)*uu(i-1,j-1,k-1) &
                  + ss(i,j,k, 2)*uu(i  ,j-1,k-1) &
                  + ss(i,j,k, 3)*uu(i+1,j-1,k-1) &
                  + ss(i,j,k, 4)*uu(i-1,j  ,k-1) &
                  + ss(i,j,k, 5)*uu(i  ,j  ,k-1) &
                  + ss(i,j,k, 6)*uu(i+1,j  ,k-1) &
                  + ss(i,j,k, 7)*uu(i-1,j+1,k-1) &
                  + ss(i,j,k, 8)*uu(i  ,j+1,k-1) &
                  + ss(i,j,k, 9)*uu(i+1,j+1,k-1) &
                  
                  + ss(i,j,k,10)*uu(i-1,j-1,k  ) &
                  + ss(i,j,k,11)*uu(i  ,j-1,k  ) &
                  + ss(i,j,k,12)*uu(i+1,j-1,k  ) &
                  + ss(i,j,k,13)*uu(i-1,j  ,k  ) &
                  + ss(i,j,k,14)*uu(i+1,j  ,k  ) &
                  + ss(i,j,k,15)*uu(i-1,j+1,k  ) &
                  + ss(i,j,k,16)*uu(i  ,j+1,k  ) &
                  + ss(i,j,k,17)*uu(i+1,j+1,k  ) &
                  
                  + ss(i,j,k,18)*uu(i-1,j-1,k+1) &
                  + ss(i,j,k,19)*uu(i  ,j-1,k+1) &
                  + ss(i,j,k,20)*uu(i+1,j-1,k+1) &
                  + ss(i,j,k,21)*uu(i-1,j  ,k+1) &
                  + ss(i,j,k,22)*uu(i  ,j  ,k+1) &
                  + ss(i,j,k,23)*uu(i+1,j  ,k+1) &
                  + ss(i,j,k,24)*uu(i-1,j+1,k+1) &
                  + ss(i,j,k,25)*uu(i  ,j+1,k+1) &
                  + ss(i,j,k,26)*uu(i+1,j+1,k+1) &
                  )
          end do
       end do
    end do
    !$OMP END PARALLEL DO

    !$OMP PARALLEL DO PRIVATE(j,i,k) IF(nz.ge.4)
    do k = 1, nz
       do j = 1, ny
          do i = 1, nx
             uu(i,j,k) = uu(i,j,k) + omega*(wrk(i,j,k)/ss(i,j,k,14)-uu(i,j,k))
          end do
       end do
    end do
    !$OMP END PARALLEL DO

    call destroy(bpt)

  end subroutine jac_dense_smoother_3d

  subroutine lgs_x_2d(omega, ss, uu, ff, lo, ng)
    integer, intent(in) :: lo(:), ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ss(lo(1):,lo(2):,0:)
    real (kind = dp_t), intent(in) :: ff(lo(1):,lo(2):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:,lo(2)-ng:)

    real (kind = dp_t) :: wrk(size(ff,dim=1),4)
    integer :: i, j, hi(size(lo))

    hi = ubound(ff)

    do j = lo(2), hi(2)
       do i = lo(1), hi(1)
          wrk(i,1:3) = ss(i,j,(/0,2,1/))
          wrk(i,4) = ff(i,j) - (ss(i,j,3)*uu(i,j+1) + ss(i,j,4)*uu(i,j-1))
       end do
       call dgtsl(wrk(:,2), wrk(:,1), wrk(:,3), wrk(:,4))
       do i = lo(1), hi(1)
          uu(i,j) = uu(i,j) + omega*(wrk(i,4)-uu(i,j))
       end do
    end do
  end subroutine lgs_x_2d

  subroutine lgs_y_2d(omega, ss, uu, ff, lo, ng)
    integer, intent(in) :: lo(:), ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ss(lo(1):,lo(2):,0:)
    real (kind = dp_t), intent(in) :: ff(lo(1):,lo(2):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:,lo(2)-ng:)
    real (kind = dp_t) :: wrk(size(ff,dim=2),4)
    integer :: i, j, hi(size(lo))
    hi = ubound(ff)
    do i = lo(1), hi(1)
       do j = lo(2), hi(2)
          wrk(j,1:3) = ss(i,j,(/0,4,3/))
          wrk(j,4) = ff(i,j) -(ss(i,j,1)*uu(i+1,j) + ss(i,j,2)*uu(i-1,j))
       end do
       call dgtsl(wrk(:,2), wrk(:,1), wrk(:,3), wrk(:,4))
       do j = lo(2), hi(2)
          uu(i,j) = uu(i,j) - omega*(wrk(j,4)-uu(i,j))
       end do
    end do
  end subroutine lgs_y_2d

  subroutine lgs_rb_x_2d(omega, ss, uu, ff, lo, ng)
    integer, intent(in) :: lo(:), ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ss(lo(1):,lo(2):,0:)
    real (kind = dp_t), intent(in) :: ff(lo(1):,lo(2):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:,lo(2)-ng:)
    real (kind = dp_t) :: wrk(size(ff,dim=1),4)
    integer :: i, j, hi(size(lo))

    hi = ubound(ff)

    ! Note: it is wasteful to use the 4 component of wrk

    do j = lo(2), hi(2), 2
       do i = lo(1), hi(1)
          wrk(i,1:3) = ss(i,j,(/0,2,1/))
          wrk(i,4) = ff(i,j) -(ss(i,j,3)*uu(i,j+1) + ss(i,j,4)*uu(i,j-1))
       end do
       call dgtsl(wrk(:,2), wrk(:,1), wrk(:,3), wrk(:,4))
       do i = lo(1), hi(1)
          uu(i,j) = uu(i,j) + omega*(wrk(i,4)-uu(i,j))
       end do
    end do

    do j = lo(2)+1, hi(2), 2
       do i = lo(1), hi(1)
          wrk(i,1:3) = ss(i,j,(/0,2,1/))
          wrk(i,4) = -(ss(i,j,3)*uu(i,j+1) + ss(i,j,4)*uu(i,j-1))
       end do
       call dgtsl(wrk(:,2), wrk(:,1), wrk(:,3), wrk(:,4))
       do i = lo(1), hi(1)
          uu(i,j) = uu(i,j) + omega*(wrk(i,4)-uu(i,j))
       end do
    end do
  end subroutine lgs_rb_x_2d

  subroutine lgs_rb_y_2d(omega, ss, uu, ff, lo, ng)
    integer, intent(in) :: lo(:), ng
    real (kind = dp_t), intent(in) :: omega
    real (kind = dp_t), intent(in) :: ss(lo(1):,lo(2):,0:)
    real (kind = dp_t), intent(in) :: ff(lo(1):,lo(2):)
    real (kind = dp_t), intent(inout) :: uu(lo(1)-ng:,lo(2)-ng:)
    real (kind = dp_t) :: wrk(size(ff,dim=2),4)
    integer :: i, j, hi(size(lo))

    hi = ubound(ff)
    do i = lo(1), hi(1), 2
       do j = lo(2), hi(2)
          wrk(j,1:3) = ss(i,j,(/0,4,3/))
          wrk(j,4) = ff(i,j) -(ss(i,j,1)*uu(i+1,j) + ss(i,j,2)*uu(i-1,j))
       end do
       call dgtsl(wrk(:,2), wrk(:,1), wrk(:,3), wrk(:,4))
       do j = lo(2), hi(2)
          uu(i,j) = uu(i,j) + omega*(wrk(j,4)-uu(i,j))
       end do
    end do

    do i = lo(1)+1, hi(1), 2
       do j = lo(2), hi(2)
          wrk(j,1:3) = ss(i,j,(/0,4,3/))
          wrk(j,4) = ff(i,j) -(ss(i,j,1)*uu(i+1,j) + ss(i,j,2)*uu(i-1,j))
       end do
       call dgtsl(wrk(:,2), wrk(:,1), wrk(:,3), wrk(:,4))
       do j = lo(2), hi(2)
          uu(i,j) = uu(i,j) + omega*(wrk(j,4)-uu(i,j))
       end do
    end do

  end subroutine lgs_rb_y_2d

  subroutine dgtsl(c, d, e, b, lpivot)
    use bl_error_module
    real (kind = dp_t), intent(inout), dimension(:) :: c, d, e, b
    logical, optional, intent(in) :: LPIVOT

    !     dgtsl given a general tridiagonal matrix and a right hand
    !     side will find the solution.

    !     on entry

    !     n       integer
    !     is the order of the tridiagonal matrix.

    !     c       real (kind = dp_t)(n)
    !     is the subdiagonal of the tridiagonal matrix.
    !     c(2) through c(n) should contain the subdiagonal.
    !     on output c is destroyed.

    !     d       real (kind = dp_t)(n)
    !     is the diagonal of the tridiagonal matrix.
    !     on output d is destroyed.

    !     e       real (kind = dp_t)(n)
    !     is the superdiagonal of the tridiagonal matrix.
    !     e(1) through e(n-1) should contain the superdiagonal.
    !     on output e is destroyed.

    !     b       real (kind = dp_t)(n)
    !     is the right hand side vector.

    !     on return

    !     b       is the solution vector.

    !     linpack. this version dated 08/14/78 .
    !     jack dongarra, argonne national laboratory.

    !     no externals
    !     fortran dabs

    !     internal variables

    integer :: k, n
    real (kind = dp_t) :: t
    real (kind = dp_t), parameter :: ZERO = 0.0_dp_t
    logical :: lpv

    lpv = .TRUE.; if ( present(lpivot) ) lpv = lpivot

    !     begin block permitting ...exits to 100

    n = size(b)
    if ( n .lt. 1 ) return
    if ( n .eq. 1 ) then
       b(1) = b(1)/d(1)
       return
    end if

    c(1) = d(1)
    d(1) = e(1)
    e(1) = ZERO
    e(n) = ZERO

    do k = 1, n-1

       ! find the largest of the two rows

       if (LPV .and. abs(c(k+1)) .ge. abs(c(k))) then

          ! interchange row

          t = c(k+1)
          c(k+1) = c(k)
          c(k) = t
          t = d(k+1)
          d(k+1) = d(k)
          d(k) = t
          t = e(k+1)
          e(k+1) = e(k)
          e(k) = t
          t = b(k+1)
          b(k+1) = b(k)
          b(k) = t
       end if

       ! zero elements

       if (c(k) .eq. ZERO) then
          call bl_error("error 0")
       end if
       t = -c(k+1)/c(k)
       c(k+1) = d(k+1) + t*d(k)
       d(k+1) = e(k+1) + t*e(k)
       e(k+1) = ZERO
       b(k+1) = b(k+1) + t*b(k)
    end do
    if (c(n) .eq. ZERO) then
       call bl_error("error 1")
    end  if

    ! back solve

    b(n) = b(n)/c(n)
    b(n-1) = (b(n-1) - d(n-1)*b(n))/c(n-1)
    do k = n-2, 1, -1
       b(k) = (b(k) - d(k)*b(k+1) - e(k)*b(k+2))/c(k)
    end do

  end subroutine dgtsl

end module cc_smoothers_module