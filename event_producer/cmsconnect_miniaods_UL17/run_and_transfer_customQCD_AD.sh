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
mv hww-tagging-dev-miniaods/event_producer/cmsconnect_miniaods_UL17/{inputs,fragments} .
# rsync -a /afs/cern.ch/user/c/coli/work/hww/hww-tagging-minis/event_producer/cmsconnect_miniaods_UL17/{inputs,fragments} . # test-only

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
EOSDNNTUPLEPATH=${8##*=}
if ! [ -z "$9" ]; then
  LHEPRODSCRIPT=${9##*=}
fi

WORKDIR=`pwd`

export SCRAM_ARCH=slc7_amd64_gcc700
export RELEASE=CMSSW_10_6_30
export RELEASE_HLT=CMSSW_9_4_14_UL_patch1
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

mkdir $CMSSW_BASE/src/GeneratorInterface
cp -rf $WORKDIR/inputs/scripts/GenCustomFilters $CMSSW_BASE/src/GeneratorInterface/GenCustomFilters

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

## NanoGEN
# cmsDriver.py Configuration/GenProduction/python/${PROCNAME}.py --python_filename wmLHEGENNANO_cfg.py --eventcontent NANOAODGEN --customise Configuration/DataProcessing/Utils.addMonitoring --datatier NANOAOD --customise_commands process.RandomNumberGeneratorService.generator.initialSeed="int(${SEED})"\\nprocess.source.numberEventsInLuminosityBlock="cms.untracked.uint32(100)" --fileout file:lhegennano.root --conditions 106X_mc2017_realistic_v6 --beamspot Realistic25ns13TeVEarly2017Collision --step LHE,GEN,NANOGEN --geometry DB:Extended --era Run2_2017 --mc -n $NEVENT --nThreads $NTHREAD || exit $? ;
## Framework job
# cmsRun -j FrameworkJobReport.xml wmLHEGENNANO_cfg.py
## Transfer
# xrdcp --silent -p -f lhegennano.root $EOSPATH
# touch dummy.cc
# if, NanoGEN, comment everything else below

# this is a GEN step
cmsDriver.py Configuration/GenProduction/python/${PROCNAME}.py --python_filename GEN_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring,GeneratorInterface/GenCustomFilters/applyFilter.apply --datatier GEN --fileout file:lhegen.root --conditions 106X_mc2017_realistic_v6 --beamspot Realistic25ns13TeVEarly2017Collision --customise_commands process.RandomNumberGeneratorService.generator.initialSeed="int(${SEED})"\\nprocess.source.numberEventsInLuminosityBlock="cms.untracked.uint32(100)" --step GEN --geometry DB:Extended --era Run2_2017 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin SIM
cmsDriver.py --python_filename SIM_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM --fileout file:sim.root --conditions 106X_mc2017_realistic_v6 --beamspot Realistic25ns13TeVEarly2017Collision --step SIM --geometry DB:Extended --filein file:lhegen.root --era Run2_2017 --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin DRPremix
# cmsDriver.py --python_filename DIGIPremix_cfg.py --eventcontent PREMIXRAW --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-DIGI --fileout file:digi.root --pileup_input "dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL17_106X_mc2017_realistic_v6-v3/PREMIX" --conditions 106X_mc2017_realistic_v6 --step DIGI,DATAMIX,L1,DIGI2RAW --procModifiers premix_stage2 --geometry DB:Extended --filein file:sim.root --datamix PreMix --era Run2_2017 --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT > digi.log 2>&1 || exit $? ; # too many output, log into file 
# using provided DIGIPremix cfg
cmsRun inputs/scripts/DIGIPremix_UL2017_template_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD

# begin HLT
# load new cmssw env
if [ -r $RELEASE_HLT/src ] ; then
  echo release $RELEASE_HLT already exists
else
  scram p CMSSW $RELEASE_HLT
fi
cd $RELEASE_HLT/src
eval `scram runtime -sh`
cd $WORKDIR
cmsDriver.py --python_filename HLT_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-RAW --fileout file:hlt.root --conditions 94X_mc2017_realistic_v15 --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' --step HLT:2e34v40 --geometry DB:Extended --filein file:digi.root --era Run2_2017 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin RECO
# reload original env
cd ${CMSSW_BASE_ORIG}/src
eval `scram runtime -sh`
cd $WORKDIR

cmsDriver.py --python_filename RECO_cfg.py --eventcontent AODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier AODSIM --fileout file:reco.root --conditions 106X_mc2017_realistic_v6 --step RAW2DIGI,L1Reco,RECO,RECOSIM --geometry DB:Extended --filein file:hlt.root --era Run2_2017 --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# # begin MiniAODv2
# cmsDriver.py --python_filename MiniAODv2_cfg.py --eventcontent MINIAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier MINIAODSIM --fileout file:miniv2.root --conditions 106X_mc2017_realistic_v9 --step PAT --procModifiers run2_miniAOD_UL --geometry DB:Extended --filein file:reco.root --era Run2_2017 --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# # begin NanoAODv9
# cmsDriver.py --python_filename NanoAODv9_cfg.py --eventcontent NANOAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier NANOAODSIM --fileout file:nanov9.root --conditions 106X_mc2017_realistic_v9 --step NANO --filein file:miniv2.root --era Run2_2017,run2_nanoAOD_106Xv2 --no_exec --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
# cmsRun -j FrameworkJobReport.xml NanoAODv9_cfg.py # produce FrameworkJobReport.xml in the last step


## Run MiniAODv2 with -j FrameworkJobReport.xml 
cmsDriver.py --python_filename MiniAODv2_cfg.py --eventcontent MINIAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier MINIAODSIM --fileout file:miniv2.root --conditions 106X_mc2017_realistic_v9 --step PAT --procModifiers run2_miniAOD_UL --geometry DB:Extended --filein file:reco.root --era Run2_2017 --runUnscheduled --no_exec --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
cmsRun -j FrameworkJobReport.xml MiniAODv2_cfg.py

# Transfer file
xrdcp --silent -p -f miniv2.root $EOSPATH
# touch dummy.cc


############ Start DNNTuples ############

export SCRAM_ARCH=slc7_amd64_gcc700
rm -rf CMSSW_10_6_30
scram p CMSSW CMSSW_10_6_30
cd CMSSW_10_6_30/src
eval `scram runtime -sh`

# use an updated onnxruntime package
curl -s --retry 10 https://raw.githubusercontent.com/colizz/DNNTuples/dev-UL-hww/Ntupler/scripts/install_onnxruntime.sh -o install_onnxruntime.sh
bash install_onnxruntime.sh
rm -f install_onnxruntime.sh

# clone this repo into "DeepNTuples" directory
git clone https://github.com/colizz/DNNTuples.git DeepNTuples -b dev-UL-hww-v9-AD
# download model
curl -s --retry 10 https://coli.web.cern.ch/coli/tmp/.230626-003937_partv2_model/ak8/V02-HidLayer/model_embed.onnx -o $CMSSW_BASE/src/DeepNTuples/Ntupler/data/InclParticleTransformer-MD/ak8/V02-HidLayer/model_embed.onnx

scram b -j $NTHREAD

cd DeepNTuples/Ntupler/test/
cmsRun DeepNtuplizerAK8.py inputFiles=file:${WORKDIR}/miniv2.root outputFile=${WORKDIR}/dnntuple.root
xrdcp --silent -p -f ${WORKDIR}/dnntuple.root $EOSDNNTUPLEPATH
touch dummy.cc
