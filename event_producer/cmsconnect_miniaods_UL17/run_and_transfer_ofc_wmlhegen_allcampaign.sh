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
CAMPAIGN=${6##*=}
BEGINSEED=${7##*=}
EOSPATH=${8##*=}
if ! [ -z "$9" ]; then
  LHEPRODSCRIPT=${9##*=}
fi

WORKDIR=`pwd`

export SCRAM_ARCH=slc7_amd64_gcc700
export RELEASE=CMSSW_10_6_30
source /cvmfs/cms.cern.ch/cmsset_default.sh

if [ -r $RELEASE/src ] ; then
  echo release $RELEASE already exists
else
  scram p CMSSW $RELEASE
fi
cd $RELEASE/src
eval `scram runtime -sh`
CMSSW_BASE_ORIG=${CMSSW_BASE}

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
# 2016APV: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?contains=B2G-RunIISummer20UL16HLTAPV-05906&page=0&shown=15
# 2016: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?contains=B2G-RunIISummer20UL16wmLHEGEN-08000&page=0&shown=15
# 2017: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?contains=B2G-RunIISummer20UL17HLT-05947&page=0&shown=15
# 2018: https://cms-pdmv-prod.web.cern.ch/mcm/chained_requests?contains=B2G-RunIISummer20UL18HLT-05979&page=0&shown=15

# campaign-specific settings
if [ "$CAMPAIGN" == "UL16APV" ]; then
  CAMPAIGN_ERA=Run2_2016_HIPM
  CAMPAIGN_GLOBALTAG=106X_mcRun2_asymptotic_preVFP_v8
  CAMPAIGN_GLOBALTAGSIM=106X_mcRun2_asymptotic_preVFP_v8
  CAMPAIGN_GLOBALTAGMINI=106X_mcRun2_asymptotic_preVFP_v11
  CAMPAIGN_BEAMSPOT=Realistic25ns13TeV2016Collision
  CAMPAIGN_PILEUP_INPUT="dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL16_106X_mcRun2_asymptotic_v13-v1/PREMIX"
elif [ "$CAMPAIGN" == "UL16" ]; then
  CAMPAIGN_ERA=Run2_2016
  CAMPAIGN_GLOBALTAG=106X_mcRun2_asymptotic_v13
  CAMPAIGN_GLOBALTAGSIM=106X_mcRun2_asymptotic_v13
  CAMPAIGN_GLOBALTAGMINI=106X_mcRun2_asymptotic_v17
  CAMPAIGN_BEAMSPOT=Realistic25ns13TeV2016Collision
  CAMPAIGN_PILEUP_INPUT="dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL16_106X_mcRun2_asymptotic_v13-v1/PREMIX"
elif [ "$CAMPAIGN" == "UL17" ]; then
  CAMPAIGN_ERA=Run2_2017
  CAMPAIGN_GLOBALTAG=106X_mc2017_realistic_v6
  CAMPAIGN_GLOBALTAGSIM=106X_mc2017_realistic_v6
  CAMPAIGN_GLOBALTAGMINI=106X_mc2017_realistic_v9
  CAMPAIGN_BEAMSPOT=Realistic25ns13TeVEarly2017Collision
  CAMPAIGN_PILEUP_INPUT="dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL17_106X_mc2017_realistic_v6-v3/PREMIX site=T2_CH_CERN"
elif [ "$CAMPAIGN" == "UL18" ]; then
  CAMPAIGN_ERA=Run2_2018
  CAMPAIGN_GLOBALTAG=106X_upgrade2018_realistic_v4
  CAMPAIGN_GLOBALTAGSIM=106X_upgrade2018_realistic_v11_L1v1
  CAMPAIGN_GLOBALTAGMINI=106X_upgrade2018_realistic_v16_L1v1
  CAMPAIGN_BEAMSPOT=Realistic25ns13TeVEarly2018Collision
  CAMPAIGN_PILEUP_INPUT="dbs:/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL18_106X_upgrade2018_realistic_v11_L1v1-v2/PREMIX site=T2_CH_CERN"
else
  echo "Unknown campaign: $CAMPAIGN"
  exit 1
fi


# begin LHEGEN
SEED=$(((${BEGINSEED} + ${JOBNUM}) * 100))

# this is a LHE+GEN step
# reminder: remember to identify process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})" and externalLHEProducer->generator!!
cmsDriver.py Configuration/GenProduction/python/${PROCNAME}.py --python_filename wmLHEGEN_cfg.py --eventcontent RAWSIM,LHE --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN,LHE --fileout file:lhegen.root --conditions $CAMPAIGN_GLOBALTAG --beamspot $CAMPAIGN_BEAMSPOT --customise_commands process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})"\\nprocess.source.numberEventsInLuminosityBlock="cms.untracked.uint32(${NEVENTLUMIBLOCK})" --step LHE,GEN --geometry DB:Extended --era $CAMPAIGN_ERA --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin SIM
cmsDriver.py --python_filename SIM_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM --fileout file:sim.root --conditions $CAMPAIGN_GLOBALTAGSIM --beamspot $CAMPAIGN_BEAMSPOT --step SIM --geometry DB:Extended --filein file:lhegen.root --era $CAMPAIGN_ERA --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin DRPremix
# cmsDriver.py --python_filename DIGIPremix_cfg.py --eventcontent PREMIXRAW --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-DIGI --fileout file:digi.root --pileup_input "$CAMPAIGN_PILEUP_INPUT" --conditions $CAMPAIGN_GLOBALTAGSIM --step DIGI,DATAMIX,L1,DIGI2RAW --procModifiers premix_stage2 --geometry DB:Extended --filein file:sim.root --datamix PreMix --era $CAMPAIGN_ERA --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT > digi.log 2>&1 || exit $? ; # too many output, log into file 
# using provided DIGIPremix cfg
if [ $CAMPAIGN == "UL16APV" ]; then
  cmsRun inputs/scripts/DIGIPremix_UL2016APV_template_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD
elif [ $CAMPAIGN == "UL16" ]; then
  cmsRun inputs/scripts/DIGIPremix_UL2016_template_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD
elif [ $CAMPAIGN == "UL17" ]; then
  ## acquire pileup_input list requiring --site=T2_CH_CERN
  cmsRun inputs/scripts/DIGIPremix_UL2017_template_cernt2_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD
elif [ $CAMPAIGN == "UL18" ]; then
  ## acquire pileup_input list requiring --site=T2_CH_CERN
  cmsRun inputs/scripts/DIGIPremix_UL2018_template_cernt2_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD
fi

# begin HLT
# load new cmssw env
if [ $CAMPAIGN == "UL16APV" ] || [ "$CAMPAIGN" == "UL16" ]; then
  RELEASE_HLT=CMSSW_8_0_36_UL_patch2
  SCRAM_ARCH_HLT=slc7_amd64_gcc530
elif [ $CAMPAIGN == "UL17" ]; then
  RELEASE_HLT=CMSSW_9_4_14_UL_patch1
  SCRAM_ARCH_HLT=slc7_amd64_gcc630
elif [ $CAMPAIGN == "UL18" ]; then
  RELEASE_HLT=CMSSW_10_2_16_UL
  SCRAM_ARCH_HLT=slc7_amd64_gcc700
fi

export SCRAM_ARCH=$SCRAM_ARCH_HLT
if [ -r $RELEASE_HLT/src ] ; then
  echo release $RELEASE_HLT already exists
else
  scram p CMSSW $RELEASE_HLT
fi
cd $RELEASE_HLT/src
eval `scram runtime -sh`
cd $WORKDIR

if [ $CAMPAIGN == "UL16APV" ] || [ "$CAMPAIGN" == "UL16" ]; then
  cmsDriver.py --python_filename HLT_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --inputCommands "keep *","drop *_*_BMTF_*","drop *PixelFEDChannel*_*_*_*" --outputCommand "keep *_mix_*_*,keep *_genPUProtons_*_*" --datatier GEN-SIM-RAW --fileout file:hlt.root --conditions 80X_mcRun2_asymptotic_2016_TrancheIV_v6 --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' --step HLT:25ns15e33_v4 --geometry DB:Extended --filein file:digi.root --era Run2_2016 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
elif [ $CAMPAIGN == "UL17" ]; then
  cmsDriver.py --python_filename HLT_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-RAW --fileout file:hlt.root --conditions 94X_mc2017_realistic_v15 --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' --step HLT:2e34v40 --geometry DB:Extended --filein file:digi.root --era Run2_2017 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
elif [ $CAMPAIGN == "UL18" ]; then
  cmsDriver.py --python_filename HLT_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-RAW --fileout file:hlt.root --conditions 102X_upgrade2018_realistic_v15 --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' --step HLT:2018v32 --geometry DB:Extended --filein file:digi.root --era Run2_2018 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
fi

# begin RECO
# reload original env
export SCRAM_ARCH=slc7_amd64_gcc700
cd ${CMSSW_BASE_ORIG}/src
eval `scram runtime -sh`
cd $WORKDIR

if [ $CAMPAIGN == "UL16APV" ] || [ "$CAMPAIGN" == "UL16" ] || [ $CAMPAIGN == "UL17" ]; then
  cmsDriver.py --python_filename RECO_cfg.py --eventcontent AODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier AODSIM --fileout file:reco.root --conditions $CAMPAIGN_GLOBALTAGSIM --step RAW2DIGI,L1Reco,RECO,RECOSIM --geometry DB:Extended --filein file:hlt.root --era $CAMPAIGN_ERA --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
elif [ $CAMPAIGN == "UL18" ]; then
  cmsDriver.py --python_filename RECO_cfg.py --eventcontent AODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier AODSIM --fileout file:reco.root --conditions $CAMPAIGN_GLOBALTAGSIM --step RAW2DIGI,L1Reco,RECO,RECOSIM,EI --geometry DB:Extended --filein file:hlt.root --era $CAMPAIGN_ERA --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
fi

# begin MiniAODv2
# note: use a miniAOD-specific global tag
cmsDriver.py --python_filename MiniAODv2_cfg.py --eventcontent MINIAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier MINIAODSIM --fileout file:miniv2.root --conditions $CAMPAIGN_GLOBALTAGMINI --step PAT --procModifiers run2_miniAOD_UL --geometry DB:Extended --filein file:reco.root --era $CAMPAIGN_ERA --runUnscheduled --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# Transfer file
xrdcp --silent -p -f miniv2.root $EOSPATH
touch dummy.cc
