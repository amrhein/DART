#!/bin/csh
#
# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download
#
# DART $Id$


# init_ensemble_var.csh - script that creates perturbed initial
#                         conditions from the WRF-VAR system.
#                         (perts are drawn from the perturbation bank)
#
# created Nov. 2007, Ryan Torn NCAR/MMM
# modified by G. Romine 2011-2018

set initial_date = ${1}
set paramfile    = ${2}
source $paramfile

cd ${RUN_DIR}

set gdate  = (`echo $initial_date 0h -g | ${DART_DIR}/models/wrf/work/advance_time`)
set gdatef = (`echo $initial_date ${ASSIM_INT_HOURS}h -g | ${DART_DIR}/models/wrf/work/advance_time`)
set wdate  =  `echo $initial_date 0h -w | ${DART_DIR}/models/wrf/work/advance_time`
set yyyy   = `echo $initial_date | cut -b1-4`
set mm     = `echo $initial_date | cut -b5-6`
set dd     = `echo $initial_date | cut -b7-8`
set hh     = `echo $initial_date | cut -b9-10`

${COPY} ${SHELL_SCRIPTS_DIR}/add_bank_perts.ncl .
${COPY} ${SHELL_SCRIPTS_DIR}/new_advance_model.csh .
${COPY} ${TEMPLATE_DIR}/namelist.input.meso namelist.input
${COPY} ${TEMPLATE_DIR}/input.nml.template input.nml
${REMOVE} ${RUN_DIR}/WRF
${LINK} ${OUTPUT_DIR}/${initial_date} WRF

set n = 1
while ( $n <= $NUM_ENS )

   echo "  QUEUEING ENSEMBLE MEMBER $n at `date`"

   mkdir -p ${RUN_DIR}/advance_temp${n}

   # TJH why does the run_dir/*/input.nml come from the template_dir and not the rundir?
   # TJH furthermore, template_dir/input.nml.template and rundir/input.nml are identical. SIMPLIFY.

   ${LINK} ${RUN_DIR}/WRF_RUN/* ${RUN_DIR}/advance_temp${n}/.
   ${LINK} ${TEMPLATE_DIR}/input.nml.template ${RUN_DIR}/advance_temp${n}/input.nml

   ${COPY} ${OUTPUT_DIR}/${initial_date}/wrfinput_d01_${gdate[1]}_${gdate[2]}_mean \
           ${RUN_DIR}/advance_temp${n}/wrfvar_output.nc
   sleep 3
   ${COPY} ${RUN_DIR}/add_bank_perts.ncl ${RUN_DIR}/advance_temp${n}/.

   set cmd3 = "ncl 'MEM_NUM=${n}' ${RUN_DIR}/advance_temp${n}/add_bank_perts.ncl"
   ${REMOVE} ${RUN_DIR}/advance_temp${n}/nclrun3.out
          cat >!    ${RUN_DIR}/advance_temp${n}/nclrun3.out << EOF
          $cmd3
EOF
   echo $cmd3 >! ${RUN_DIR}/advance_temp${n}/nclrun3.out.tim   # TJH replace cat above

   cat >! ${RUN_DIR}/rt_assim_init_${n}.csh << EOF
#!/bin/csh
#=================================================================
#PBS -N first_advance_${n}
#PBS -j oe
#PBS -A ${CNCAR_GAU_ACCOUNT}
#PBS -l walltime=${CADVANCE_TIME}
#PBS -q ${CADVANCE_QUEUE}
#PBS -m ae
#PBS -M ${CEMAIL}
#PBS -l select=${CADVANCE_NODES}:ncpus=${CADVANCE_PROCS}:mpiprocs=${CADVANCE_MPI}
#=================================================================

   echo "rt_assim_init_${n}.csh is running in `pwd`"

   cd ${RUN_DIR}/advance_temp${n}

   if (-e wrfvar_output.nc) then
      echo "Running nclrun3.out to create wrfinput_d01 for member $n at `date`"

      chmod +x nclrun3.out
      ./nclrun3.out >& add_perts.out
      ${MOVE} wrfvar_output.nc wrfinput_d01
   endif

   cd $RUN_DIR

   echo "Running first_advance.csh for member $n at `date`"
   ${SHELL_SCRIPTS_DIR}/first_advance.csh $initial_date $n ${SHELL_SCRIPTS_DIR}/$paramfile

EOF

   qsub ${RUN_DIR}/rt_assim_init_${n}.csh

   @ n++

end

exit 0

# <next few lines under version control, do not edit>
# $URL$
# $Revision$
# $Date$
