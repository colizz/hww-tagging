#!/bin/bash

#script to run generic lhe generation tarballs
#kept as simply as possible to minimize need
#to update the cmssw release
#(all the logic goes in the run script inside the tarball
# on frontier)
#J.Bendavid

#exit on first error
set -e

echo "   ______________________________________     "
echo "         Running Generic Tarball/Gridpack     "
echo "   ______________________________________     "

path=${1}
echo "gridpack tarball path = $path"

nevt=${2}
echo "%MSG-MG5 number of events requested = $nevt"

rnum=${3}
echo "%MSG-MG5 random seed used for the run = $rnum"

ncpu=${4}
echo "%MSG-MG5 thread count requested = $ncpu"

echo "%MSG-MG5 residual/optional arguments = ${@:5}"

if [ -n "${5}" ]; then
  use_gridpack_env=${5}
  echo "%MSG-MG5 use_gridpack_env = $use_gridpack_env"
fi

if [ -n "${6}" ]; then
  scram_arch_version=${6}
  echo "%MSG-MG5 override scram_arch_version = $scram_arch_version"
fi

if [ -n "${7}" ]; then
  cmssw_version=${7}
  echo "%MSG-MG5 override cmssw_version = $cmssw_version"
fi

LHEWORKDIR=`pwd`

if [ "$use_gridpack_env" = false -a -n "$scram_arch_version" -a -n  "$cmssw_version" ]; then
  echo "%MSG-MG5 CMSSW version = $cmssw_version"
  export SCRAM_ARCH=${scram_arch_version}
  scramv1 project CMSSW ${cmssw_version}
  cd ${cmssw_version}/src
  eval `scramv1 runtime -sh`
  cd $LHEWORKDIR
fi

if [[ -d lheevent ]]
    then
    echo 'lheevent directory found'
    echo 'Setting up the environment'
    rm -rf lheevent
fi
mkdir lheevent; cd lheevent

#untar the tarball directly from cvmfs
tar -xaf ${path} 

# If TMPDIR is unset, set it to the condor scratch area if present
# and fallback to /tmp
export TMPDIR=${TMPDIR:-${_CONDOR_SCRATCH_DIR:-/tmp}}

#generate events
./runcmsgrid.sh $nevt $rnum $ncpu ${@:5}

########## Do JHUGen job! ##########
if [ ! -f $LHEWORKDIR/JHUGenerator.tar.gz ]; then
  echo "Download JHUGen..."
  curl https://spin.pha.jhu.edu/Generator/JHUGenerator.v7.5.0.tar.gz --output $LHEWORKDIR/JHUGenerator.tar.gz
fi
tar xaf $LHEWORKDIR/JHUGenerator.tar.gz

## modify the Z mass to keep the nH/mZ ratio
MH=$(echo $path | grep -P '(?<=_MH)\d+(?=_)' -o)
MZ=$(echo "scale=3; $MH / 125 * 91.1876" | bc)
sed -i "s/M_Z     = 91.1876d0/M_Z     = ${MZ}d0/g" JHUGenerator.v7.5.0/JHUGenerator/mod_Parameters.F90
echo "%MSG-JHUGen modify the Z mass to ${MZ}. Input params: MH = ${MH}"

JHUBASE=`pwd`
pushd JHUGenerator.v7.5.0/JHUGenerator/
make

# Run JHUGEN
# prob(4q) : pro(llqq) = 1:2
CHOICE=(1 2 3)
if [ ${CHOICE[RANDOM%3]} == "1" ]; then
  JHUCMD="DecayMode1=1 DecayMode2=1"
else
  JHUCMD="DecayMode1=8 DecayMode2=1"
fi
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# 1. switch the two higgs boson
python ${SCRIPT_DIR}/lhe_modifier.py -m switch -i ${JHUBASE}/cmsgrid_final.lhe -o ${JHUBASE}/cmsgrid_final_s.lhe
# 2. use JHUGen to decay the "last" higgs
./JHUGen ReadLHE=${JHUBASE}/cmsgrid_final_s.lhe DataFile=${JHUBASE}/cmsgrid_final_s_jhu.lhe ${JHUCMD}
# 3. switch the two higgs boson again
python ${SCRIPT_DIR}/lhe_modifier.py -m switch -i ${JHUBASE}/cmsgrid_final_s_jhu.lhe -o ${JHUBASE}/cmsgrid_final_s_jhu_s.lhe
# 4. use JHUGen to decay the "last" higgs (i.e. the real last higgs)
./JHUGen ReadLHE=${JHUBASE}/cmsgrid_final_s_jhu_s.lhe DataFile=${JHUBASE}/cmsgrid_final_s_jhu_s_jhu.lhe ${JHUCMD}
# 5. correct the LHE
python ${SCRIPT_DIR}/lhe_modifier.py -m correct -i ${JHUBASE}/cmsgrid_final_s_jhu_s_jhu.lhe -o ${JHUBASE}/cmsgrid_final_s_jhu_s_jhu_c.lhe

popd
rm -rf cmsgrid_final.lhe
mv cmsgrid_final_s_jhu_s_jhu_c.lhe cmsgrid_final.lhe

########## END ##########

mv cmsgrid_final.lhe $LHEWORKDIR/

cd $LHEWORKDIR

#cleanup working directory (save space on worker node for edm output)
rm -rf lheevent

exit 0




