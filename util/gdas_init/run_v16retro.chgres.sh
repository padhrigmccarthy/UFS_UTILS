#!/bin/bash

copy_data()
{

mkdir -p $SAVEDIR
cp gfs_ctrl.nc $SAVEDIR

for tile in 'tile1' 'tile2' 'tile3' 'tile4' 'tile5' 'tile6'
do
  cp out.atm.${tile}.nc  ${SAVEDIR}/gfs_data.${tile}.nc
  cp out.sfc.${tile}.nc  ${SAVEDIR}/sfc_data.${tile}.nc 
done
}

#---------------------------------------------------------------------------
# Run chgres for gdas/enkf members using v16 parallel data as input.
# The enkf data is not saved.  So the coldstart files for all
# 80 members are simply copies of a single run of chgres using the
# gdas warm restart files as input.
#
# The gfs tarballs only have the netcdf history files.  To run 
# chgres_cube for the gfs member using the history files, the
# run_chgres.v16.sh script is used.
#---------------------------------------------------------------------------

set -x

MEMBER=$1

FIX_FV3=$UFS_DIR/fix
FIX_ORO=${FIX_FV3}/orog
FIX_AM=${FIX_FV3}/am

date10=`$NDATE -6 $yy$mm$dd$hh`
yy_d=$(echo $date10 | cut -c1-4)
mm_d=$(echo $date10 | cut -c5-6)
dd_d=$(echo $date10 | cut -c7-8)
hh_d=$(echo $date10 | cut -c9-10)

YMDH=${yy}${mm}${dd}.${hh}0000

WORKDIR=${WORKDIR:-$OUTDIR/work.${MEMBER}}

if [ ${MEMBER} == 'hires' ]; then
  CINP=${CINP:-"C768"}
  CTAR=${CRES_HIRES}
else  
  CINP=${CINP:-"C768"}
  CTAR=${CRES_ENKF}
fi

# Some parallel tarballs have 'atmos' in their directory path.  And
# some do not.

if [ -d "${EXTRACT_DIR}/gdas.${yy_d}${mm_d}${dd_d}/${hh_d}/atmos/RESTART" ]; then
  INPUT_DATA_DIR="${EXTRACT_DIR}/gdas.${yy_d}${mm_d}${dd_d}/${hh_d}/atmos/RESTART"
else
  INPUT_DATA_DIR="${EXTRACT_DIR}/gdas.${yy_d}${mm_d}${dd_d}/${hh_d}/RESTART"
fi

if [ -d "${EXTRACT_DIR}/gdas.${yy}${mm}${dd}/${hh}/atmos" ]; then
  RADSTAT_DATA_DIR="${EXTRACT_DIR}/gdas.${yy}${mm}${dd}/${hh}/atmos"
else
  RADSTAT_DATA_DIR="${EXTRACT_DIR}/gdas.${yy}${mm}${dd}/${hh}"
fi

rm -fr $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

cat << EOF > fort.41

&config
 fix_dir_target_grid="${FIX_ORO}/${CTAR}/fix_sfc"
 mosaic_file_target_grid="${FIX_ORO}/${CTAR}/${CTAR}_mosaic.nc"
 orog_dir_target_grid="${FIX_ORO}/${CTAR}"
 orog_files_target_grid="${CTAR}_oro_data.tile1.nc","${CTAR}_oro_data.tile2.nc","${CTAR}_oro_data.tile3.nc","${CTAR}_oro_data.tile4.nc","${CTAR}_oro_data.tile5.nc","${CTAR}_oro_data.tile6.nc"
 mosaic_file_input_grid="${FIX_ORO}/${CINP}/${CINP}_mosaic.nc"
 orog_dir_input_grid="${FIX_ORO}/${CINP}"
 orog_files_input_grid="${CINP}_oro_data.tile1.nc","${CINP}_oro_data.tile2.nc","${CINP}_oro_data.tile3.nc","${CINP}_oro_data.tile4.nc","${CINP}_oro_data.tile5.nc","${CINP}_oro_data.tile6.nc"
 data_dir_input_grid="${INPUT_DATA_DIR}"
 atm_core_files_input_grid="${YMDH}.fv_core.res.tile1.nc","${YMDH}.fv_core.res.tile2.nc","${YMDH}.fv_core.res.tile3.nc","${YMDH}.fv_core.res.tile4.nc","${YMDH}.fv_core.res.tile5.nc","${YMDH}.fv_core.res.tile6.nc","${YMDH}.fv_core.res.nc"
 atm_tracer_files_input_grid="${YMDH}.fv_tracer.res.tile1.nc","${YMDH}.fv_tracer.res.tile2.nc","${YMDH}.fv_tracer.res.tile3.nc","${YMDH}.fv_tracer.res.tile4.nc","${YMDH}.fv_tracer.res.tile5.nc","${YMDH}.fv_tracer.res.tile6.nc"
 vcoord_file_target_grid="${FIX_AM}/global_hyblev.l${LEVS}.txt"
 sfc_files_input_grid="${YMDH}.sfc_data.tile1.nc","${YMDH}.sfc_data.tile2.nc","${YMDH}.sfc_data.tile3.nc","${YMDH}.sfc_data.tile4.nc","${YMDH}.sfc_data.tile5.nc","${YMDH}.sfc_data.tile6.nc"
 cycle_mon=$mm
 cycle_day=$dd
 cycle_hour=$hh
 convert_atm=.true.
 convert_sfc=.true.
 convert_nst=.true.
 tracers="sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"
 tracers_input="sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"
/
EOF

$APRUN $UFS_DIR/exec/chgres_cube
rc=$?

if [ $rc != 0 ]; then
  exit $rc
fi

if [ ${MEMBER} == 'hires' ]; then
  SAVEDIR=$OUTDIR/gdas.${yy}${mm}${dd}/${hh}/atmos/INPUT
  copy_data
  cp $RADSTAT_DATA_DIR/*abias* $SAVEDIR/..
  cp $RADSTAT_DATA_DIR/*radstat $SAVEDIR/..
  touch $SAVEDIR/../gdas.t${hh}z.loginc.txt
else  
  MEMBER=1
  while [ $MEMBER -le 80 ]; do
  if [ $MEMBER -lt 10 ]; then
    MEMBER_CH="00${MEMBER}"
  else
    MEMBER_CH="0${MEMBER}"
  fi
  SAVEDIR=$OUTDIR/enkfgdas.${yy}${mm}${dd}/${hh}/atmos/mem${MEMBER_CH}/INPUT
  copy_data
  touch $SAVEDIR/../enkfgdas.t${hh}z.loginc.txt
  MEMBER=$(( $MEMBER + 1 ))
  done
fi

rm -fr $WORKDIR

set +x
echo CHGRES COMPLETED FOR MEMBER $MEMBER

exit 0
