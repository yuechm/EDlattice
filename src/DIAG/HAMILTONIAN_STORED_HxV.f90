! > BUILD SPARSE HAMILTONIAN of the SECTOR
MODULE ED_HAMILTONIAN_STORED_HxV
  USE ED_HAMILTONIAN_COMMON
  implicit none
  private


  !>Sparse Matric constructors
  public :: ed_buildh_main
  public :: ed_buildh_kondo

  !>Sparse Mat-Vec product using stored sparse matrix
  public  :: spMatVec_main
  public  :: spMatVec_kondo
#ifdef _MPI
  public  :: spMatVec_MPI_main
  public  :: spMatVec_MPI_kondo
#endif


contains


  subroutine ed_buildh_main(Hmat)
    complex(8),dimension(:,:),optional    :: Hmat
    integer                               :: isector,ispin,i,j
    complex(8),dimension(:,:),allocatable :: Htmp_up,Htmp_dw,Hrdx,Hmat_tmp
    integer,dimension(2)                  :: Indices    ![2-2*Norb]
    integer,dimension(1,Ns)               :: Nups,Ndws  ![1,Ns]-[Norb,1+Nbath]
    integer,dimension(Ns)                 :: Nup,Ndw
    real(8),dimension(Ns)                 :: Sz 
    complex(8),dimension(Nspin,Ns,Ns)     :: Hij,Hloc
    real(8),dimension(Nspin,Ns)           :: Hdiag
    !
#ifdef _MPI
    if(Mpistatus .AND. MpiComm == MPI_COMM_NULL)return
#endif
    !
    if(.not.Hsector%status)stop "ed_buildh_main ERROR: Hsector NOT allocated"
    isector=Hsector%index
    !
    if(present(Hmat))&
         call assert_shape(Hmat,[getdim(isector), getdim(isector)],"ed_buildh_main","Hmat")
    !
    call Hij_get(Hij)
    call Hij_get(Hloc)
    do ispin=1,Nspin
       Hdiag(ispin,:) = dreal(diagonal(Hloc(ispin,:,:)))
    enddo
    !
#ifdef _MPI
    if(MpiStatus)then
       call sp_set_mpi_matrix(MpiComm,spH0d,mpiIstart,mpiIend,mpiIshift)
       call sp_init_matrix(MpiComm,spH0d,DimUp*DimDw)
       if(Jhflag)then
          call sp_set_mpi_matrix(MpiComm,spH0nd,mpiIstart,mpiIend,mpiIshift)
          call sp_init_matrix(MpiComm,spH0nd,DimUp*DimDw)
       endif
    else
       call sp_init_matrix(spH0d,DimUp*DimDw)
       if(Jhflag)call sp_init_matrix(spH0nd,DimUp*DimDw)
    endif
#else
    call sp_init_matrix(spH0d,DimUp*DimDw)
    if(Jhflag)call sp_init_matrix(spH0nd,DimUp*DimDw)
#endif
    call sp_init_matrix(spH0dws(1),DimDw)
    call sp_init_matrix(spH0ups(1),DimUp)
    !
    !-----------------------------------------------!
    !LOCAL HAMILTONIAN TERMS
    include "stored/H_local.f90"    
    !
    !NON-LOCAL HAMILTONIAN TERMS
    include "stored/H_non_local.f90"
    !
    !UP TERMS
    include "stored/H_up.f90"
    !
    !DW TERMS
    include "stored/H_dw.f90"
    !
    !-----------------------------------------------!
    if(present(Hmat))then
       Hmat = zero
       allocate(Htmp_up(DimUp,DimUp));Htmp_up=zero
       allocate(Htmp_dw(DimDw,DimDw));Htmp_dw=zero
       allocate(Hmat_tmp(DimUp*DimDw,DimUp*DimDw));Hmat_tmp=zero
       !
#ifdef _MPI
       if(MpiStatus)then
          call sp_dump_matrix(MpiComm,spH0d,Hmat_tmp)
       else
          call sp_dump_matrix(spH0d,Hmat_tmp)
       endif
#else
       call sp_dump_matrix(spH0d,Hmat_tmp)
#endif
       !
       if(Jhflag)then
          allocate(Hrdx(DimUp*DimDw,DimUp*DimDw));Hrdx=zero
#ifdef _MPI
          if(MpiStatus)then
             call sp_dump_matrix(MpiComm,spH0nd,Hrdx)
          else
             call sp_dump_matrix(spH0nd,Hrdx)
          endif
#else
          call sp_dump_matrix(spH0nd,Hrdx)
#endif
          Hmat_tmp = Hmat_tmp + Hrdx
          deallocate(Hrdx)
       endif
       !
       call sp_dump_matrix(spH0ups(1),Htmp_up)
       call sp_dump_matrix(spH0dws(1),Htmp_dw)
       Hmat_tmp = Hmat_tmp + kronecker_product(Htmp_dw,zeye(DimUp))
       Hmat_tmp = Hmat_tmp + kronecker_product(zeye(DimDw),Htmp_up)
       !
       Hmat = Hmat_tmp
       !
       deallocate(Htmp_up,Htmp_dw,Hmat_tmp)
    endif
    !
    return
    !
  end subroutine ed_buildh_main




  subroutine ed_buildH_kondo(Hmat)
    complex(8),dimension(:,:),optional  :: Hmat
    integer                             :: isector,ispin,i,j
    integer,dimension(2*Ns)             :: ib
    integer,dimension(eNs)              :: Nup,Ndw
    real(8),dimension(eNs)              :: Sz
    integer,dimension(iNs)              :: NpUp,NpDw
    real(8),dimension(iNs)              :: Szp
    complex(8),dimension(Nspin,eNs,eNs) :: Hij,Hloc
    real(8),dimension(Nspin,eNs)        :: Hdiag
    integer                             :: io_up,io_dw,imp_up,imp_dw
    !
#ifdef _MPI
    if(Mpistatus .AND. MpiComm == MPI_COMM_NULL)return
#endif
    !
    if(.not.Hsector%status)stop "ed_buildh_kondo ERROR: Hsector NOT allocated"
    isector=Hsector%index
    !
    if(present(Hmat))&
         call assert_shape(Hmat,[getdim(isector), getdim(isector)],"ed_buildh_kondo","Hmat")
    !
    call Hij_get(Hij)
    call Hij_get(Hloc)
    do ispin=1,Nspin
       Hdiag(ispin,:) = dreal(diagonal(Hloc(ispin,:,:)))
    enddo
    !
    !
    !
#ifdef _MPI
    if(MpiStatus)then
       call sp_set_mpi_matrix(MpiComm,spH0d,mpiIstart,mpiIend,mpiIshift)
       call sp_init_matrix(MpiComm,spH0d,Dim)
    else
       call sp_init_matrix(spH0d,Dim)
    endif
#else
    call sp_init_matrix(spH0d,Dim)
#endif
    !
    !-----------------------------------------------!
    !
    !LOCAL HAMILTONIAN TERMS
    include "stored/H_diag.f90"
    !
    !NON-LOCAL INTERACTION HAMILTONIAN TERMS
    include "stored/H_se_ph.f90"
    ! !
    !KONDO COUPLING HAMILTONIAN TERMS
    include "stored/H_kondo.f90"
    ! !
    !HOPPING TERMS
    include "stored/H_hop.f90"
    !
    !-----------------------------------------------!
    !
    !
    if(present(Hmat))then
#ifdef _MPI
       if(MpiStatus)then
          call sp_dump_matrix(MpiComm,spH0d,Hmat)
       else
          call sp_dump_matrix(spH0d,Hmat)
       endif
#else
       call sp_dump_matrix(spH0d,Hmat)
#endif          
    endif
    !
  end subroutine ed_buildH_kondo













  !####################################################################
  !        SPARSE MAT-VEC PRODUCT USING STORED SPARSE MATRIX 
  !####################################################################
  !+------------------------------------------------------------------+
  !PURPOSE: Perform the matrix-vector product H*v used in the
  ! - serial
  ! - MPI
  !+------------------------------------------------------------------+
  subroutine spMatVec_main(Nloc,v,Hv)
    integer                    :: Nloc
    complex(8),dimension(Nloc) :: v
    complex(8),dimension(Nloc) :: Hv
    complex(8)                 :: val
    integer                    :: i,iup,idw,j,jup,jdw,jj
    !
    !
    Hv=zero
    !
    !Local:
    do i = 1,Nloc
       do jj=1,spH0d%row(i)%Size
          val = spH0d%row(i)%vals(jj)
          j = spH0d%row(i)%cols(jj)
          Hv(i) = Hv(i) + val*v(j)
       enddo
    enddo
    !
    !DW:
    do iup=1,DimUp
       do idw=1,DimDw
          i = iup + (idw-1)*DimUp
          do jj=1,spH0dws(1)%row(idw)%Size
             jup = iup
             jdw = spH0dws(1)%row(idw)%cols(jj)
             val = spH0dws(1)%row(idw)%vals(jj)
             j     = jup +  (jdw-1)*DimUp
             Hv(i) = Hv(i) + val*V(j)
          enddo
       enddo
       !
    enddo
    !
    !UP:
    do idw=1,DimDw
       !
       do iup=1,DimUp
          i = iup + (idw-1)*DimUp
          do jj=1,spH0ups(1)%row(iup)%Size
             jup = spH0ups(1)%row(iup)%cols(jj)
             jdw = idw
             val = spH0ups(1)%row(iup)%vals(jj)
             j =  jup + (jdw-1)*DimUp
             Hv(i) = Hv(i) + val*V(j)
          enddo
       enddo
       !
    enddo
    !
    !Non-Local:
    if(jhflag)then
       do i = 1,Nloc         
          do jj=1,spH0nd%row(i)%Size
             val = spH0nd%row(i)%vals(jj)
             j = spH0nd%row(i)%cols(jj)
             Hv(i) = Hv(i) + val*v(j)
          enddo
       enddo
    endif
    !
  end subroutine spMatVec_main

  subroutine spMatVec_kondo(Nloc,v,Hv)
    integer                         :: Nloc
    complex(8),dimension(Nloc)      :: v
    complex(8),dimension(Nloc)      :: Hv
    integer                         :: i,j
    Hv=zero
    do i=1,Nloc
       matmul: do j=1,spH0d%row(i)%Size
          Hv(i) = Hv(i) + spH0d%row(i)%vals(j)*v(spH0d%row(i)%cols(j))
       end do matmul
    end do
  end subroutine spMatVec_kondo





#ifdef _MPI
  subroutine spMatVec_mpi_main(Nloc,v,Hv)
    integer                             :: Nloc
    complex(8),dimension(Nloc)          :: v
    complex(8),dimension(Nloc)          :: Hv
    !
    integer                             :: N
    complex(8),dimension(:),allocatable :: vt,Hvt
    complex(8),dimension(:),allocatable :: vin
    complex(8)                          :: val
    integer                             :: i,iup,idw,j,jup,jdw,jj
    integer                             :: irank
    !
    ! if(MpiComm==Mpi_Comm_Null)return
    ! if(MpiComm==MPI_UNDEFINED)stop "spMatVec_mpi_cc ERROR: MpiComm = MPI_UNDEFINED"
    if(.not.MpiStatus)stop "spMatVec_mpi_cc ERROR: MpiStatus = F"
    !
    !Evaluate the local contribution: Hv_loc = Hloc*v
    Hv=zero
    do i=1,Nloc                 !==spH0%Nrow
       do jj=1,spH0d%row(i)%Size
          val = spH0d%row(i)%vals(jj)
          Hv(i) = Hv(i) + val*v(i)
       enddo
    end do
    !
    !Non-local terms.
    !UP part: contiguous in memory.
    do idw=1,MpiQdw
       do iup=1,DimUp
          i = iup + (idw-1)*DimUp
          hxv_up: do jj=1,spH0ups(1)%row(iup)%Size
             jup = spH0ups(1)%row(iup)%cols(jj)
             jdw = idw
             val = spH0ups(1)%row(iup)%vals(jj)
             j   = jup + (idw-1)*DimUp
             Hv(i) = Hv(i) + val*v(j)
          end do hxv_up
       enddo
    end do
    !
    !DW part: non-contiguous in memory -> MPI transposition
    !Transpose the input vector as a whole:
    mpiQup=DimUp/MpiSize
    if(MpiRank<mod(DimUp,MpiSize))MpiQup=MpiQup+1
    !
    allocate(vt(mpiQup*DimDw))
    allocate(Hvt(mpiQup*DimDw))
    vt=0d0
    Hvt=0d0
    call vector_transpose_MPI(DimUp,MpiQdw,v(1:DimUp*MpiQdw),DimDw,MpiQup,vt)
    do idw=1,MpiQup             !<= Transposed order:  column-wise DW <--> UP  
       do iup=1,DimDw           !<= Transposed order:  column-wise DW <--> UP
          i = iup + (idw-1)*DimDw
          hxv_dw: do jj=1,spH0dws(1)%row(iup)%Size
             jup = spH0dws(1)%row(iup)%cols(jj)
             jdw = idw             
             j   = jup + (jdw-1)*DimDw
             val = spH0dws(1)%row(iup)%vals(jj)
             Hvt(i) = Hvt(i) + val*vt(j)
          end do hxv_dw
       enddo
    end do
    deallocate(vt) ; allocate(vt(DimUp*mpiQdw)) ; vt=0d0
    call vector_transpose_MPI(DimDw,mpiQup,Hvt,DimUp,mpiQdw,vt)
    Hv(1:DimUp*MpiQdw) = Hv(1:DimUp*MpiQdw) + Vt
    deallocate(vt,Hvt)
    !
    !
    !Non-Local:
    if(jhflag)then
       N = 0
       call AllReduce_MPI(MpiComm,Nloc,N)
       ! 
       allocate(vt(N)) ; vt = 0d0
       call allgather_vector_MPI(MpiComm,v,vt)
       !
       do i=1,Nloc
          matmul: do jj=1,spH0nd%row(i)%Size
             val = spH0nd%row(i)%vals(jj)
             j = spH0nd%row(i)%cols(jj)
             Hv(i) = Hv(i) + val*Vt(j)
          enddo matmul
       enddo
       deallocate(Vt)
    endif
    !
  end subroutine spMatVec_mpi_main


  subroutine spMatVec_mpi_kondo(Nloc,v,Hv)
    integer                             :: Nloc
    complex(8),dimension(Nloc)          :: v
    complex(8),dimension(Nloc)          :: Hv
    integer                             :: i,j,mpiIerr
    integer                             :: N,MpiShift
    complex(8),dimension(:),allocatable :: vin
    integer,allocatable,dimension(:)    :: Counts,Offset
    !
    !
    if(MpiComm==MPI_UNDEFINED)stop "spHtimesV_mpi_cc ERRROR: MpiComm = MPI_UNDEFINED"
    if(.not.MpiStatus)stop "spMatVec_mpi_cc ERROR: MpiStatus = F"
    !
    MpiRank = get_Rank_MPI(MpiComm)
    MpiSize = get_Size_MPI(MpiComm)
    !
    N = 0
    call AllReduce_MPI(MpiComm,Nloc,N)
    !
    !Evaluate the local contribution: Hv_loc = Hloc*v
    MpiShift = spH0d%Ishift
    Hv=0d0
    do i=1,Nloc
       local: do j=1,spH0d%loc(i)%Size
          Hv(i) = Hv(i) + spH0d%loc(i)%vals(j)*v(spH0d%loc(i)%cols(j)-MpiShift)
       end do local
    end do
    !
    allocate(Counts(0:MpiSize-1)) ; Counts(0:)=0
    allocate(Offset(0:MpiSize-1)) ; Offset(0:)=0
    !
    Counts(0:)        = N/MpiSize
    Counts(MpiSize-1) = N/MpiSize+mod(N,MpiSize)
    !
    do i=1,MpiSize-1
       Offset(i) = Counts(i-1) + Offset(i-1)
    enddo
    !
    allocate(vin(N)) ; vin = zero
    call MPI_Allgatherv(&
         v(1:Nloc),Nloc,MPI_Double_Complex,&
         vin      ,Counts,Offset,MPI_Double_Complex,&
         MpiComm,MpiIerr)
    !
    do i=1,Nloc                 !==spH0d%Nrow
       matmul: do j=1,spH0d%row(i)%Size
          Hv(i) = Hv(i) + spH0d%row(i)%vals(j)*vin(spH0d%row(i)%cols(j))
       end do matmul
    end do
    !
  end subroutine spMatVec_mpi_kondo
#endif



end MODULE ED_HAMILTONIAN_STORED_HXV







