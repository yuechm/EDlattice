MODULE ED_VARS_GLOBAL
  USE SF_CONSTANTS
  USE ED_SPARSE_MATRIX
  USE ED_GRAPH_MATRIX
#ifdef _MPI
  USE MPI
  USE SF_MPI
#endif
  implicit none





  !---------------- SECTOR-TO-FOCK SPACE STRUCTURE -------------------!

  type sector_map
     integer,dimension(:),allocatable :: map
     logical                          :: status=.false.
  end type sector_map

  type sector
     integer                                     :: index       !
     type(sector_map),dimension(:),allocatable   :: H
     integer,dimension(:),allocatable            :: DimUps
     integer,dimension(:),allocatable            :: DimDws
     integer                                     :: DimUp
     integer                                     :: DimDw
     integer                                     :: DimEl
     integer                                     :: DimPh
     integer                                     :: Dim
     integer,dimension(:),allocatable            :: Nups
     integer,dimension(:),allocatable            :: Ndws
     integer                                     :: Nup
     integer                                     :: Ndw
     integer                                     :: Nlanc
     logical                                     :: status=.false.
  end type sector



  !------------------ ABTRACT INTERFACES PROCEDURES ------------------!
  !SPARSE MATRIX-VECTOR PRODUCTS USED IN ED_MATVEC
  !dbleMat*dbleVec
  abstract interface
     subroutine dd_sparse_HxV(Nloc,v,Hv)
       integer                 :: Nloc
       real(8),dimension(Nloc) :: v
       real(8),dimension(Nloc) :: Hv
     end subroutine dd_sparse_HxV
  end interface




  !-------------------------- ED  VARIABLES --------------------------!

  !SIZE OF THE PROBLEM
  !=========================================================
  integer,save                                     :: Ns       !Number of levels per spin
  integer,save                                     :: Nsectors !Number of sectors
  integer,save                                     :: Ns_orb
  integer,save                                     :: Ns_ud


  !Some maps between sectors and full Hilbert space (pointers)
  !PRIVATE:
  !=========================================================
  integer,allocatable,dimension(:)                 :: getDim             ! [Nsectors]
  integer,allocatable,dimension(:,:,:)             :: getCsector         ! [1/Norb,2,NSectors]
  integer,allocatable,dimension(:,:,:)             :: getCDGsector       ! [1/Norb,2,NSectors]
  integer,allocatable,dimension(:,:)               :: impIndex
  logical,allocatable,dimension(:)                 :: twin_mask
  logical,allocatable,dimension(:)                 :: sectors_mask

  !internal Hmatrix storage
  !PRIVATE
  !=========================================================  
  real(8),allocatable,dimension(:,:,:,:,:,:)       :: impHij

  !Variables for DIAGONALIZATION
  !PRIVATE
  !=========================================================  
  type(sparse_matrix_csr)                          :: spH0d !diagonal part
  type(sparse_matrix_csr)                          :: spH0nd !non-diagonal part
  type(sparse_matrix_csr),dimension(:),allocatable :: spH0ups,spH0dws !reduced UP and DW parts
  type(sparse_matrix_csr)                          :: spH0_ph !Hamiltonian for phonons
  type(sparse_matrix_csr)                          :: spH0e_eph, spH0edw_eph, spH0ph_eph !electron-phonon interaction
  !
  procedure(dd_sparse_HxV),pointer                 :: spHtimesV_p=>null()


  !Variables for DIAGONALIZATION
  !PRIVATE
  !=========================================================  
  integer,allocatable,dimension(:)                 :: neigen_sector
  logical                                          :: trim_state_list=.false.

  !Partition function
  !PRIVATE
  !=========================================================
  real(8)                                          :: zeta_function
  real(8)                                          :: gs_energy




  !Impurity Green's function and Self-Energies: (Ns,Ns,:)
  !PRIVATE (now public but accessible thru routine)
  !=========================================================
  complex(8),allocatable,dimension(:,:,:,:)        :: impSmats ![Nspin,Ns,Ns,Freq]
  complex(8),allocatable,dimension(:,:,:,:)        :: impSreal
  complex(8),allocatable,dimension(:,:,:,:)        :: impGmats
  complex(8),allocatable,dimension(:,:,:,:)        :: impGreal
  complex(8),allocatable,dimension(:,:,:,:)        :: impG0mats
  complex(8),allocatable,dimension(:,:,:,:)        :: impG0real



  !Density and double occupancy
  !PRIVATE (now public but accessible thru routines)
  !=========================================================
  real(8),dimension(:),allocatable                 :: ed_dens
  real(8),dimension(:),allocatable                 :: ed_dens_up,ed_dens_dw
  real(8),dimension(:),allocatable                 :: ed_docc
  real(8),dimension(:),allocatable                 :: ed_mag
  real(8)                                          :: ed_Ekin
  real(8)                                          :: ed_Epot
  real(8)                                          :: ed_Eint
  real(8)                                          :: ed_Ehartree
  real(8)                                          :: ed_Eknot
  real(8)                                          :: ed_Dust,ed_Dund,ed_Dse,ed_Dph



  !Frequency and time arrays:
  !=========================================================
  real(8),dimension(:),allocatable                 :: wm,tau,wr,vm,vr


  !Impurity operators
  !PRIVATE (now public but accessible thru routine)
  !=========================================================
  complex(8),allocatable,dimension(:,:,:)          :: imp_density_matrix



  !File suffixes for printing fine tuning.
  !=========================================================
  integer                                          :: site_indx_padding=4
  logical                                          :: Jhflag              !spin-exchange and pair-hopping flag.
  logical                                          :: offdiag_gf_flag=.false.
  logical                                          :: finiteT             !flag for finite temperature calculation


  !This is the internal Mpi Communicator and variables.
  !=========================================================
#ifdef _MPI
  integer                                          :: MpiComm_Global=MPI_COMM_NULL
  integer                                          :: MpiComm=MPI_COMM_NULL
#endif
  integer                                          :: MpiGroup_Global=MPI_GROUP_NULL
  integer                                          :: MpiGroup=MPI_GROUP_NULL
  logical                                          :: MpiStatus=.false.
  logical                                          :: MpiMaster=.true.
  integer                                          :: MpiRank=0
  integer                                          :: MpiSize=1
  integer,allocatable,dimension(:)                 :: MpiMembers
  integer                                          :: mpiQup=0
  integer                                          :: mpiRup=0
  integer                                          :: mpiQdw=0
  integer                                          :: mpiRdw=0
  integer                                          :: mpiQ=0
  integer                                          :: mpiR=0
  integer                                          :: mpiIstart
  integer                                          :: mpiIend
  integer                                          :: mpiIshift
  logical                                          :: mpiAllThreads=.true.
  !

contains






  !=========================================================
  subroutine ed_set_MpiComm(comm)
#ifdef _MPI
    integer :: comm,ierr
    ! call MPI_Comm_dup(Comm,MpiComm_Global,ierr)
    ! call MPI_Comm_dup(Comm,MpiComm,ierr)
    MpiComm_Global = comm
    MpiComm        = comm
    call Mpi_Comm_group(MpiComm_Global,MpiGroup_Global,ierr)
    MpiStatus      = .true.
    MpiSize        = get_Size_MPI(MpiComm_Global)
    MpiRank        = get_Rank_MPI(MpiComm_Global)
    MpiMaster      = get_Master_MPI(MpiComm_Global)
#else
    integer,optional :: comm
#endif
  end subroutine ed_set_MpiComm

  subroutine ed_del_MpiComm()
#ifdef _MPI    
    MpiComm_Global = MPI_UNDEFINED
    MpiComm        = MPI_UNDEFINED
    MpiGroup_Global= MPI_GROUP_NULL
    MpiStatus      = .false.
    MpiSize        = 1
    MpiRank        = 0
    MpiMaster      = .true.
#endif
  end subroutine ed_del_MpiComm




END MODULE ED_VARS_GLOBAL
