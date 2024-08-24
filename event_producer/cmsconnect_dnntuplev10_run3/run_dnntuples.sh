#!/bin/bash -xe

INPUTFILES=$1
CMSRUNARGS=$2
EOSPATH=$3
BRANCHNAME=$4
if [ -z "$BRANCHNAME" ]; then
  BRANCHNAME="dev-Run3-hww"
fi

WORKDIR=`pwd`

source /cvmfs/cms.cern.ch/cmsset_default.sh

############ Start DNNTuples ############
export SCRAM_ARCH=el9_amd64_gcc12
scram p CMSSW CMSSW_14_0_11
cd CMSSW_14_0_11/src
eval `scram runtime -sh`

# clone this repo into "DeepNTuples" directory
git clone https://github.com/colizz/DNNTuples.git DeepNTuples -b $BRANCHNAME
# download model
curl -s --retry 10 https://coli.web.cern.ch/coli/tmp/.230626-003937_partv2_model/ak8/V02-HidLayer/model_embed.onnx -o $CMSSW_BASE/src/DeepNTuples/Ntupler/data/InclParticleTransformer-MD/ak8/V02-HidLayer/model_embed.onnx

scram b -j8

cd DeepNTuples/Ntupler/test/

function retry {
  local n=1
  local max=5
  local delay=5
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
        echo "The command has failed after $n attempts."
        return 1
      fi
    }
  done
}

### process files iteratively
IFS=',' read -ra ADDR <<< "$INPUTFILES"
idx=0
for infile in "${ADDR[@]}"; do
  echo $infile $idx
  retry cmsRun DeepNtuplizerAK8.py inputFiles=${infile} ${CMSRUNARGS}
  mv output.root dnntuple_raw${idx}.root
  idx=$(($idx+1))
done
if [ $idx == 1 ]; then
  mv dnntuple_raw0.root dnntuple.root
else
  hadd dnntuple.root dnntuple_raw*.root
fi
### end processing file

mv dnntuple.root ${WORKDIR}/dnntuple.root

if ! [ -z "$EOSPATH" ]; then
  xrdcp --silent -p -f ${WORKDIR}/dnntuple.root $EOSPATH
fi
touch ${WORKDIR}/dummy.cc
