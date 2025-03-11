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

sleep $(( ( RANDOM % 200 ) + 1 ))

wget --tries=3 https://github.com/colizz/hww-tagging/archive/refs/heads/dev-miniaods.tar.gz
tar xaf dev-miniaods.tar.gz
mv hww-tagging-dev-miniaods/event_producer/cmsconnect_miniaods_scouting_Run3/{inputs,fragments} .
# rsync -a /afs/cern.ch/user/c/coli/work/hww/hww-tagging-minis/event_producer/cmsconnect_miniaods_Run3_haa/{inputs,fragments} . # test-only

# xrdcp root://eoscms.cern.ch//store/cmst3/group/vhcc/sfTuples/downloads/MG5_aMC_v2.9.18.tar.gz inputs/MG5_aMC_v2.9.18.tar.gz

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

export SCRAM_ARCH=el8_amd64_gcc12
export RELEASE=CMSSW_14_0_19
export RELEASE_SKIM=CMSSW_15_0_0_pre3
source /cvmfs/cms.cern.ch/cmsset_default.sh

if [ -r $RELEASE/src ] ; then
  echo release $RELEASE already exists
else
  scram p CMSSW $RELEASE
fi
cd $RELEASE/src
eval `scram runtime -sh`
CMSSW_BASE_ORIG=${CMSSW_BASE}

# customize CMSSW code

# mkdir $CMSSW_BASE/src/GeneratorInterface
# cp -rf /cvmfs/cms.cern.ch/$SCRAM_ARCH/cms/cmssw/$CMSSW_VERSION/src/GeneratorInterface/{Core,LHEInterface} $CMSSW_BASE/src/GeneratorInterface/
# # copy customized LHE production script
# cp -f $WORKDIR/inputs/scripts/{lhe_modifier.py,run_instMG.sh} GeneratorInterface/LHEInterface/data/
# # use customized LHE production script, if specified
# if ! [ -z $LHEPRODSCRIPT ]; then
#   cp -f $WORKDIR/inputs/scripts/$LHEPRODSCRIPT GeneratorInterface/LHEInterface/data/
#   sed -i "s|run_generic_tarball_cvmfs.sh|${LHEPRODSCRIPT}|g" GeneratorInterface/Core/src/BaseHadronizer.cc
# else
#   sed -i "s|run_generic_tarball_cvmfs.sh|run_instMG.sh|g" GeneratorInterface/Core/src/BaseHadronizer.cc
# fi

# copy the fragment
mkdir -p Configuration/GenProduction/python/
cp $WORKDIR/fragments/${PROCNAME}.py Configuration/GenProduction/python/${PROCNAME}.py
# replace the event number
# NOTE: this routine does not specify NEVENT in the fragment
# grep -q "__NEVENT__" Configuration/GenProduction/python/${PROCNAME}.py || exit $? ;
sed "s/__NEVENT__/$NEVENT/g" -i Configuration/GenProduction/python/${PROCNAME}.py
eval `scram runtime -sh`
scram b -j $NTHREAD

cd $WORKDIR

# following workflows 20UL chain
# copied from https://cms-pdmv.cern.ch/mcm/chained_requests?contains=SUS-RunIISummer20UL17NanoAODv9-00044&page=0&shown=15

# begin LHEGEN
# SEED=$(($(date +%s) % 100000 + 1))
# SEED=$((${BEGINSEED} + ${JOBNUM}))
SEED=$(((${BEGINSEED} + ${JOBNUM}) * 100))

GLOBALTAG=140X_mcRun3_2024_realistic_v26
GLOBALTAG_SKIM=150X_mcRun3_2024_realistic_v1

## NanoGEN
# cmsDriver.py Configuration/GenProduction/python/${PROCNAME}.py --python_filename wmLHEGENNANO_cfg.py --eventcontent NANOAODGEN --customise Configuration/DataProcessing/Utils.addMonitoring --datatier NANOAOD --customise_commands process.RandomNumberGeneratorService.generator.initialSeed="int(${SEED})"\\nprocess.source.numberEventsInLuminosityBlock="cms.untracked.uint32(100)" --fileout file:lhegennano.root --conditions 140X_mcRun3_2024_realistic_v26 --beamspot Realistic25ns13TeVEarly2017Collision --step LHE,GEN,NANOGEN --geometry DB:Extended --era Run2_2017 --mc -n $NEVENT --nThreads $NTHREAD || exit $? ;
## Framework job
# cmsRun -j FrameworkJobReport.xml wmLHEGENNANO_cfg.py
## Transfer
# xrdcp --silent -p -f lhegennano.root $EOSPATH
# touch dummy.cc
# if, NanoGEN, comment everything else below

# need to specify seeds otherwise gridpacks will be chosen from the same routine!!
# remember to identify process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})" and externalLHEProducer->generator!!

cmsDriver.py Configuration/GenProduction/python/${PROCNAME}.py --python_filename GS_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM --fileout file:gensim.root --conditions $GLOBALTAG --beamspot DBrealistic --customise_commands process.RandomNumberGeneratorService.generator.initialSeed="int(${SEED})"\\nprocess.source.numberEventsInLuminosityBlock="cms.untracked.uint32(${NEVENTLUMIBLOCK})" --step GEN,SIM --geometry DB:Extended --era Run3_2024 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin DRPremix
# cmsDriver.py --python_filename DIGIPremix_cfg.py --eventcontent PREMIXRAW --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-DIGI --fileout file:digi.root --pileup_input "dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL17_140X_mcRun3_2024_realistic_v26-v3/PREMIX" --conditions 140X_mcRun3_2024_realistic_v26 --step DIGI,DATAMIX,L1,DIGI2RAW --procModifiers premix_stage2 --geometry DB:Extended --filein file:sim.root --datamix PreMix --era Run2_2017 --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT > digi.log 2>&1 || exit $? ; # too many output, log into file 
# using provided DIGIPremix cfg
cmsRun inputs/scripts/DIGIPremix_Run3_2024_template_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD

cmsDriver.py  --python_filename RECO_cfg.py --eventcontent AODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier AODSIM --fileout file:reco.root --conditions $GLOBALTAG --step RAW2DIGI,L1Reco,RECO,RECOSIM --geometry DB:Extended --filein file:hlt.root --era Run3_2024 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# Change to CMSSW_15_0_0_pre3 before SKIM

if [ -r $RELEASE_SKIM/src ] ; then
  echo release $RELEASE_SKIM already exists
else
  scram p CMSSW $RELEASE_SKIM
fi
cd $RELEASE_SKIM/src
eval `scram runtime -sh`
cd $WORKDIR

# Run MiniAODv6 with -j FrameworkJobReport.xml 
cmsDriver.py  --python_filename MiniAODv6_cfg.py --eventcontent MINIAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier MINIAODSIM --fileout file:miniv6.root --conditions $GLOBALTAG_SKIM --step PAT --geometry DB:Extended --filein file:reco.root --era Run3_2024 --no_exec --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
cmsRun -j FrameworkJobReport.xml MiniAODv6_cfg.py
# Transfer file
xrdcp --silent -p -f miniv6.root $EOSPATH
touch dummy.cc

# ############ Start DNNTuples ############
# # use CMSSW_11_1_0_pre8 which has Puppi V14
# export SCRAM_ARCH=slc7_amd64_gcc820
# scram p CMSSW CMSSW_11_1_0_pre8
# cd CMSSW_11_1_0_pre8/src
# eval `scram runtime -sh`

# git cms-addpkg PhysicsTools/ONNXRuntime
# # clone this repo into "DeepNTuples" directory
# git clone https://github.com/colizz/DNNTuples.git DeepNTuples -b dev-UL-hww
# # Use a faster version of ONNXRuntime
# $CMSSW_BASE/src/DeepNTuples/Ntupler/scripts/install_onnxruntime.sh
# scram b -j $NTHREAD

# # Must run inside the test folder..
# cd DeepNTuples/Ntupler/test/
# cmsRun DeepNtuplizerAK8.py inputFiles=file:${WORKDIR}/miniv2.root outputFile=${WORKDIR}/dnntuple.root
