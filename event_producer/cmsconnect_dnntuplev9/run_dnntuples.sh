#!/bin/bash -xe

INPUTFILES=$1
CMSRUNARGS=$2
EOSPATH=$3
BRANCHNAME=$4
if [ -z "$BRANCHNAME" ]; then
  BRANCHNAME="dev-UL-hww"
fi

WORKDIR=`pwd`

source /cvmfs/cms.cern.ch/cmsset_default.sh

############ Start DNNTuples ############
export SCRAM_ARCH=slc7_amd64_gcc700
scram p CMSSW CMSSW_10_6_30
cd CMSSW_10_6_30/src
eval `scram runtime -sh`

# use an updated onnxruntime package
curl -s --retry 10 https://raw.githubusercontent.com/colizz/DNNTuples/dev-UL-hww/Ntupler/scripts/install_onnxruntime.sh -o install_onnxruntime.sh
bash install_onnxruntime.sh
rm -f install_onnxruntime.sh

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
