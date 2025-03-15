#!/bin/bash
# Script to generate LHE events instantly from MG, without using tarball/gridpack.
#   author: Congqiao Li

echo "   _________________________________________________     "
echo "         Running Instant MG without Tarball/Gridpack     "
echo "   _________________________________________________     "

if [[ -d lheevent ]]
    then
    echo 'lheevent directory found'
    echo 'Setting up the environment'
    rm -rf lheevent
fi
mkdir lheevent
WORKDIR=`pwd`/lheevent
INPUTDIR=`pwd`/inputs

## processing input

INSTRING=${1}
echo "%MSG-MG5 instMG string = $INSTRING"
# instMG string should following the format: instMG://PROC_NAME/MG_VERSION/CUSTOM_ARGS
#   e.g. instMG://BulkGraviton_WW_VariableMass_WhadWhad/MG5_aMC_v2.6.5/5400:110

if [[ $INSTRING != instMG://* ]]; then
   echo "Format error..."
   exit 1
fi
IFS='/' read -ra SEG <<< "$INSTRING"
SEG_NN=() # non-empty segmentation
for s in ${SEG[@]}; do 
  SEG_NN=(${SEG_NN[@]} $s)
done
PROC_NAME=${SEG_NN[1]}
MG_VERSION=${SEG_NN[2]}
IFS=':' read -ra ARGS <<< "${SEG_NN[3]}" # custom arguments, split by ':'

echo "%MSG-MG5 >> input processs name = $PROC_NAME"
echo "%MSG-MG5 >> input MG version = $MG_VERSION"
echo "%MSG-MG5 >> input arguments for MG customized card = ${ARGS[@]}"

# basedir should already include:
#  - input cards folder `InputCards`
#  - MG tarball (optional)
#  - MG model folder (optional) `model`
#  - MG patches folder `patches` (should manually copy from genproduction)

# Example structure:
# inputs
# ├── InputCards
# │   ├── BulkGraviton_WW_VariableMass_WhadWhad_customizecards.dat
# │   ├── BulkGraviton_WW_VariableMass_WhadWhad_proc_card_instMG.dat
# │   └── BulkGraviton_WW_VariableMass_WhadWhad_run_card_instMG.dat
# ├── MG5_aMC_v2.6.5.tar.gz
# ├── model
# │   └── dibosonResonanceModel.tar.gz
# └── patches
#     ├── 0001-add-additional-restrict-files-for-sm-models.patch
#     ├── 0002-skip-modification-of-masses-at-NLO-for-pythia8-since.patch
#     └── ....

# notice on the InputCards
#  The run card is copied from the internal MG "Cards" folder when generating events 
#  from a target process, and should not contain any placeholder (e.g. for LHAPDF).
#  The systematics module can be removed if not needed.

NEVENT=${2}
echo "%MSG-MG5 number of events requested = $NEVENT"

RNUM=${3}
echo "%MSG-MG5 random seed used for the run = $RNUM"


cd $WORKDIR

## setup environment
export SCRAM_ARCH=el8_amd64_gcc11
export RELEASE=CMSSW_13_0_20
source /cvmfs/cms.cern.ch/cmsset_default.sh

if [ -r $RELEASE/src ] ; then
  echo release $RELEASE already exists
else
  scram p CMSSW $RELEASE
fi
cd $RELEASE/src
eval `scram runtime -sh`
# necessary config for LHAPDF
export BOOSTINCLUDES=`scram tool tag boost INCLUDE`

## initiate MadGraph
cd $WORKDIR
MGTAR=${MG_VERSION}.tar.gz
if [[ ! -f $INPUTDIR/$MGTAR ]]; then
  wget --no-check-certificate https://cms-project-generators.web.cern.ch/cms-project-generators/$MGTAR
  tar xaf $MGTAR
else
  tar xaf $INPUTDIR/$MGTAR
fi

MGBASEDIRORIG=$(echo ${MG_VERSION} | tr "." "_")
cd $MGBASEDIRORIG

# apply patches
cat $INPUTDIR/patches/*.patch | patch -p1

# load model
cd models
for model in `\ls $INPUTDIR/model/`; do
  if [[ $model == *".zip"* ]]; then
    unzip $INPUTDIR/model/$model
  elif [[ $model == *".tgz"* ]]; then
    tar zxvf $INPUTDIR/model/$model
  elif [[ $model == *".tar"* ]]; then
    tar xavf $INPUTDIR/model/$model
  fi
done
cd ..

## config MG before first run
echo "set auto_update 0" > mgconfigscript
echo "set automatic_html_opening False" >> mgconfigscript
LHAPDFCONFIG=`echo "$LHAPDF_DATA_PATH/../../bin/lhapdf-config"`
echo "set lhapdf_py3 $LHAPDFCONFIG" >> mgconfigscript
echo "set run_mode 0" >> mgconfigscript
echo "save options" >> mgconfigscript

./bin/mg5_aMC mgconfigscript

## output process folder
cp $INPUTDIR/InputCards/${PROC_NAME}_proc_card_instMG.dat proc_card.dat
sed -i "s|__FULLPATH__|${WORKDIR}/${MGBASEDIRORIG}/models|g" proc_card.dat
./bin/mg5_aMC proc_card.dat
mv $PROC_NAME processtmp
cd processtmp

## generate events
# replace run card
rm -f ./Cards/run_card.dat
cp $INPUTDIR/InputCards/${PROC_NAME}_run_card_instMG.dat ./Cards/run_card.dat

# lhapdf set
echo "lhapdf_py3 = $LHAPDFCONFIG" >> ./Cards/me5_configuration.txt

# prepare customized card
cp $INPUTDIR/InputCards/${PROC_NAME}_customizecards_instMG.dat customizecards.dat
for i in `seq 1 ${#ARGS[@]}`; do
  sed -i "s/\$${i}/${ARGS[$((i-1))]}/g" customizecards.dat
done

# write launching script (customized config inside)
echo "done" > makegrid.dat
echo "set gridpack False" >> makegrid.dat  # disable gridpack mode
echo "set nevents $NEVENT" >> makegrid.dat 
echo "set iseed $RNUM" >> makegrid.dat

cat customizecards.dat >> makegrid.dat
echo "done" >> makegrid.dat

# launch
cat makegrid.dat | ./bin/generate_events pilotrun --nb_core=1

gzip -d ./Events/pilotrun/unweighted_events.lhe.gz
mv ./Events/pilotrun/unweighted_events.lhe $WORKDIR/../cmsgrid_final.lhe


########## Do JHUGen job! ##########
mv $WORKDIR/../cmsgrid_final.lhe $WORKDIR/
cd $WORKDIR

if [ ! -f $INPUTDIR/JHUGenerator.tar.gz ]; then
  echo "Download JHUGen..."
  xrdcp root://cmseos.fnal.gov//store/user/lpcdihiggsboost/MINIAOD/ParTSamples/JHUGenerator.v7.5.0.tar.gz $INPUTDIR/JHUGenerator.tar.gz
fi
tar xaf $INPUTDIR/JHUGenerator.tar.gz

## modify the Z mass to keep the mH/mZ ratio
# MH=$(echo $path | grep -P '(?<=_MH)\d+(?=_)' -o) # get MH from gridpack path
MH=${ARGS[1]}
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
mv cmsgrid_final_s_jhu_s_jhu_c.lhe $WORKDIR/../cmsgrid_final.lhe

########## END ##########


cd $WORKDIR/..
rm -rf lheevent
