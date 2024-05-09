#!/bin/bash -xe

## NOTE: difference made w.r.t. common exe script
## 1. __NEVENT__ not specify in the fragment
## 2. no LHE step, also need to change externalLHEProducer to generator
## 3. seeds have width 100

## in additinal to cmsconnect_higgs version:
## 4. use custom cmssw (rsync from cvmfs)
## 5. download MG
## 6. use provided DIGI cfg
## 7. stop running dnntuples

# sleep $(( ( RANDOM % 200 ) + 1 ))

wget --tries=3 https://github.com/colizz/hww-tagging/archive/refs/heads/dev-miniaods.tar.gz
tar xaf dev-miniaods.tar.gz
mv hww-tagging-dev-miniaods/event_producer/cmsconnect_miniaods_UL17/{inputs,fragments} .
# rsync -a /afs/cern.ch/user/c/coli/work/hww/hww-tagging-minis/event_producer/cmsconnect_miniaods_UL17/{inputs,fragments} . # test-only

xrdcp root://cmseos.fnal.gov//store/user/lpcdihiggsboost/MINIAOD/ParTSamples/MG5_aMC_v2.6.5.tar.gz inputs/MG5_aMC_v2.6.5.tar.gz

if [ -d /afs/cern.ch/user/${USER:0:1}/$USER ]; then
  export HOME=/afs/cern.ch/user/${USER:0:1}/$USER # crucial on lxplus condor but cannot set on cmsconnect!
fi
env

JOBNUM=${1##*=} # hard coded by crab
NEVENT=${2##*=} # ordered by crab.py script
NEVENTLUMIBLOCK=${3##*=} # ordered by crab.py script
NTHREAD=${4##*=} # ordered by crab.py script
PROCNAME=${5##*=} # ordered by crab.py script
BEGINSEED=${6##*=}
EOSPATH=${7##*=}
if ! [ -z "$8" ]; then
  LHEPRODSCRIPT=${8##*=}
fi

WORKDIR=`pwd`

export SCRAM_ARCH=el8_amd64_gcc10
export RELEASE_BASE=CMSSW_12_4_14_patch3
export RELEASE_MINIAOD=CMSSW_13_0_13
source /cvmfs/cms.cern.ch/cmsset_default.sh

if [ -r $RELEASE_BASE/src ] ; then
  echo release $RELEASE_BASE already exists
else
  scram p CMSSW $RELEASE_BASE
fi

CMSSW_BASE_ORIG=${CMSSW_BASE}

# # # customize CMSSW code
# mkdir $CMSSW_BASE/src/GeneratorInterface
# # cp -rf /cvmfs/cms.cern.ch/$SCRAM_ARCH/cms/cmssw/$CMSSW_VERSION/src/GeneratorInterface/{Core,LHEInterface} $CMSSW_BASE/src/GeneratorInterface/
# # copy customized LHE production script
# cp -f $WORKDIR/inputs/scripts/{lhe_modifier.py,run_instMG.sh} GeneratorInterface/LHEInterface/data/
# # use customized LHE production script, if specified
# if ! [ -z $LHEPRODSCRIPT ]; then
#   cp -f $WORKDIR/inputs/scripts/$LHEPRODSCRIPT GeneratorInterface/LHEInterface/data/
#   sed -i "s|run_generic_tarball_cvmfs.sh|${LHEPRODSCRIPT}|g" GeneratorInterface/Core/src/BaseHadronizer.cc
# else
#   sed -i "s|run_generic_tarball_cvmfs.sh|run_instMG.sh|g" GeneratorInterface/Core/src/BaseHadronizer.cc
# fi

# # copy the fragment
# mkdir -p Configuration/GenProduction/python/
# cp $WORKDIR/fragments/${PROCNAME}.py Configuration/GenProduction/python/${PROCNAME}.py
# # replace the event number
# # NOTE: this routine does not specify NEVENT in the fragment
# # grep -q "__NEVENT__" Configuration/GenProduction/python/${PROCNAME}.py || exit $? ;
# sed "s/__NEVENT__/$NEVENT/g" -i Configuration/GenProduction/python/${PROCNAME}.py
# eval `scram runtime -sh`
# scram b -j $NTHREAD


# Download fragment from McM
mkdir -p Configuration/GenProduction/python/
curl -s -k https://cms-pdmv-prod.web.cern.ch/mcm/public/restapi/requests/get_fragment/HIG-Run3Summer22wmLHEGS-00228 --retry 3 --create-dirs -o Configuration/GenProduction/python/HIG-Run3Summer22wmLHEGS-00228-fragment.py
[ -s Configuration/GenProduction/python/HIG-Run3Summer22wmLHEGS-00228-fragment.py ] || exit $?;

# Check if fragment contais gridpack path ant that it is in cvmfs
if grep -q "gridpacks" Configuration/GenProduction/python/HIG-Run3Summer22wmLHEGS-00228-fragment.py; then
  if ! grep -q "/cvmfs/cms.cern.ch/phys_generator/gridpacks" Configuration/GenProduction/python/HIG-Run3Summer22wmLHEGS-00228-fragment.py; then
    echo "Gridpack inside fragment is not in cvmfs."
    exit -1
  fi
fi

cd $RELEASE_BASE/src
eval `scram runtime -sh`
cp -r $WORKDIR/Configuration .
scram b -j $NTHREAD
cd $WORKDIR

# following workflows 20UL chain
# copied from https://cms-pdmv.cern.ch/mcm/chained_requests?contains=SUS-RunIISummer20UL17NanoAODv9-00044&page=0&shown=15

# begin LHEGEN
# SEED=$(($(date +%s) % 100000 + 1))
# SEED=$((${BEGINSEED} + ${JOBNUM}))
SEED=$(((${BEGINSEED} + ${JOBNUM}) * 100))


## NanoGEN
# need to specify seeds otherwise gridpacks will be chosen from the same routine!!
# remember to identify process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})" and externalLHEProducer->generator!!
# modified based on https://cms-pdmv-prod.web.cern.ch/mcm/public/restapi/requests/get_test/HIG-Run3Summer22wmLHEGS-00228 (Source: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?prepid=HIG-chain_Run3Summer22wmLHEGS_flowRun3Summer22DRPremix_flowRun3Summer22MiniAODv4_flowRun3Summer22NanoAODv12-00101&page=0&shown=15 -> HIG-Run3Summer22wmLHEGS-00228 -> Get test command)
cmsDriver.py Configuration/GenProduction/python/HIG-Run3Summer22wmLHEGS-00228-fragment.py --python_filename wmLHEGEN_cfg.py --eventcontent RAWSIM,LHE --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM,LHE --fileout file:sim.root --conditions 124X_mcRun3_2022_realistic_v12 --beamspot Realistic25ns13p6TeVEarly2022Collision --customise_commands process.RandomNumberGeneratorService.generator.initialSeed="int(${SEED})"\\nprocess.source.numberEventsInLuminosityBlock="cms.untracked.uint32(${NEVENTLUMIBLOCK})" --step LHE,GEN,SIM --geometry DB:Extended --era Run3 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;


# begin DRPremix and HLT
# load new cmssw env
# modified based on https://cms-pdmv-prod.web.cern.ch/mcm/public/restapi/requests/get_test/HIG-Run3Summer22DRPremix-00166 (Source: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?prepid=HIG-chain_Run3Summer22wmLHEGS_flowRun3Summer22DRPremix_flowRun3Summer22MiniAODv4_flowRun3Summer22NanoAODv12-00101&page=0&shown=15 -> HIG-Run3Summer22DRPremix-00166 -> Get test command)
cmsDriver.py --python_filename DIGIPremix_cfg.py --eventcontent PREMIXRAW --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-RAW --fileout file:hlt.root --pileup_input "dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX" --conditions 124X_mcRun3_2022_realistic_v12 --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2022v12 --procModifiers premix_stage2,siPixelQualityRawToDigi --geometry DB:Extended --filein file:sim.root --datamix PreMix --era Run3 --mc --nThreads $NTHREAD -n $NEVENT > digi.log 2>&1 || exit $? ; # too many output, log into file 

# begin RECO
# reload original env
# modified based on https://cms-pdmv-prod.web.cern.ch/mcm/public/restapi/requests/get_test/HIG-Run3Summer22DRPremix-00166 (Source: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?prepid=HIG-chain_Run3Summer22wmLHEGS_flowRun3Summer22DRPremix_flowRun3Summer22MiniAODv4_flowRun3Summer22NanoAODv12-00101&page=0&shown=15 -> HIG-Run3Summer22DRPremix-00166 -> Get test command)
cmsDriver.py --python_filename RECO_cfg.py --eventcontent AODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier AODSIM --fileout file:reco.root --conditions 124X_mcRun3_2022_realistic_v12 --procModifiers siPixelQualityRawToDigi --step RAW2DIGI,L1Reco,RECO,RECOSIM --geometry DB:Extended --filein file:hlt.root --era Run3 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin MiniAOD
# modified based on https://cms-pdmv-prod.web.cern.ch/mcm/public/restapi/requests/get_test/HIG-Run3Summer22MiniAODv4-00101 (Source: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?prepid=HIG-chain_Run3Summer22wmLHEGS_flowRun3Summer22DRPremix_flowRun3Summer22MiniAODv4_flowRun3Summer22NanoAODv12-00101&page=0&shown=15 -> HIG-Run3Summer22MiniAODv4-00101 -> Get test command)
export SCRAM_ARCH=el8_amd64_gcc11
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r $RELEASE_MINIAOD/src ] ; then
  echo release $RELEASE_MINIAOD already exists
else
  scram p CMSSW $RELEASE_MINIAOD
fi
cd $RELEASE_MINIAOD/src
eval `scram runtime -sh`

cp -r $WORKDIR/Configuration .
scram b
cd $WORKDIR

cmsDriver.py --python_filename MiniAODv2_cfg.py --eventcontent MINIAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier MINIAODSIM --fileout file:mini.root --conditions 130X_mcRun3_2022_realistic_v5 --step PAT --geometry DB:Extended --filein file:reco.root --era Run3 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
# cmsRun -j FrameworkJobReport.xml MiniAODv2_cfg.py # produce FrameworkJobReport.xml in the last step


# begin NanoAOD
# modified based on https://cms-pdmv-prod.web.cern.ch/mcm/public/restapi/requests/get_test/HIG-Run3Summer22NanoAODv12-00101 (Source: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?prepid=HIG-chain_Run3Summer22wmLHEGS_flowRun3Summer22DRPremix_flowRun3Summer22MiniAODv4_flowRun3Summer22NanoAODv12-00101&page=0&shown=15 -> HIG-Run3Summer22NanoAODv12-00101 -> Get test command)
cmsDriver.py --python_filename NanoAOD_cfg.py --eventcontent NANOAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier NANOAODSIM --fileout file:nano.root --conditions 130X_mcRun3_2022_realistic_v5 --step NANO --scenario pp --filein file:mini.root --era Run3 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
cmsRun -j FrameworkJobReport.xml NanoAOD_cfg.py # produce FrameworkJobReport.xml in the last step


# Transfer files
xrdcp --silent -p -f mini.root $EOSPATH
xrdcp --silent -p -f nano.root $EOSPATH

# ############ Start DNNTuples ############
# cd $WORKDIR;
# mkdir -p dnn_test;
# cd dnn_test;
# DNNDIR=`pwd`

# export SCRAM_ARCH=el8_amd64_gcc11
# export RELEASE_DNN=CMSSW_13_0_13
# if [ -r $RELEASE_DNN/src ] ; then
#   echo release $RELEASE_DNN already exists
# else
#   scram p CMSSW $RELEASE_DNN
# fi

# cd $RELEASE_DNN/src
# eval `scram runtime -sh`

# git cms-addpkg PhysicsTools/ONNXRuntime
# # clone this repo into "DeepNTuples" directory
# if ! [ -d DeepNTuples ]; then
#   git clone https://github.com/zichunhao/DNNTuples.git DeepNTuples -b dev-UL-hww
# fi
# # Use a faster version of ONNXRuntime
# curl -s --retry 10 https://coli.web.cern.ch/coli/tmp/.230626-003937_partv2_model/ak8/V02-HidLayer/model_embed.onnx -o $CMSSW_BASE/src/DeepNTuples/Ntupler/data/InclParticleTransformer-MD/ak8/V02-HidLayer/model_embed.onnx
# scram b -j $NTHREAD

# # Must run inside the test folder..
# cd DeepNTuples/Ntupler/test/
# cmsRun DeepNtuplizerAK8.py inputFiles=file:${WORKDIR}/mini.root outputFile=${DNNDIR}/dnntuple.root

# cd $WORKDIR
