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

cat /etc/os-release

# # dump the script and run in cmssw-el8
# cat <<'EndOfTestFile' > run_el8.sh
# #!/bin/bash -xe

sleep $(( ( RANDOM % 200 ) + 1 ))

wget --tries=3 https://github.com/colizz/hww-tagging/archive/refs/heads/dev-miniaods.tar.gz
tar xaf dev-miniaods.tar.gz
mv hww-tagging-dev-miniaods/event_producer/cmsconnect_miniaods_Run3/{inputs,fragments} .
# rsync -a /afs/cern.ch/user/c/coli/work/hww/hww-tagging-minis/event_producer/cmsconnect_miniaods_Run3/{inputs,fragments} . # test-only

xrdcp root://eoscms.cern.ch//store/cmst3/group/vhcc/sfTuples/downloads/MG5_aMC_v2.9.18.tar.gz inputs/MG5_aMC_v2.9.18.tar.gz

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
CMSSW_BASE_ORIG=${CMSSW_BASE}

# customize CMSSW code

mkdir $CMSSW_BASE/src/GeneratorInterface
cp -rf /cvmfs/cms.cern.ch/$SCRAM_ARCH/cms/cmssw/$CMSSW_VERSION/src/GeneratorInterface/{Core,LHEInterface} $CMSSW_BASE/src/GeneratorInterface/
# copy customized LHE production script
cp -f $WORKDIR/inputs/scripts/{lhe_modifier.py,run_instMG.sh} GeneratorInterface/LHEInterface/data/
# use customized LHE production script, if specified
if ! [ -z $LHEPRODSCRIPT ]; then
  cp -f $WORKDIR/inputs/scripts/$LHEPRODSCRIPT GeneratorInterface/LHEInterface/data/
  sed -i "s|run_generic_tarball_cvmfs.sh|${LHEPRODSCRIPT}|g" GeneratorInterface/Core/src/BaseHadronizer.cc
else
  sed -i "s|run_generic_tarball_cvmfs.sh|run_instMG.sh|g" GeneratorInterface/Core/src/BaseHadronizer.cc
fi

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

# following workflows NanoAODv13 chain
# copied from https://cms-pdmv.cern.ch/mcm/chained_requests?contains=SUS-RunIISummer20UL17NanoAODv9-00044&page=0&shown=15

# begin GENSIM
# SEED=$(($(date +%s) % 100000 + 1))
# SEED=$((${BEGINSEED} + ${JOBNUM}))
SEED=$(((${BEGINSEED} + ${JOBNUM}) * 100))

if [ "$CAMPAIGN" == "Run3Summer23" ]; then
  GLOBALTAG=130X_mcRun3_2023_realistic_v15
elif [ "$CAMPAIGN" == "Run3Summer23BPix" ]; then
  GLOBALTAG=130X_mcRun3_2023_realistic_postBPix_v6
else
  echo "Unknown campaign: $CAMPAIGN"
  exit 1
fi

# need to specify seeds otherwise gridpacks will be chosen from the same routine!!
# remember to identify process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})" and externalLHEProducer->generator!!
cmsDriver.py Configuration/GenProduction/python/${PROCNAME}.py --python_filename GS_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM --fileout file:gensim.root --conditions $GLOBALTAG --beamspot Realistic25ns13p6TeVEarly2023Collision --customise_commands process.RandomNumberGeneratorService.generator.initialSeed="int(${SEED})"\\nprocess.source.numberEventsInLuminosityBlock="cms.untracked.uint32(${NEVENTLUMIBLOCK})" --step GEN,SIM --geometry DB:Extended --era Run3_2023 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# begin DRPremix
# cmsDriver.py  --python_filename DIGIPremix_cfg.py --eventcontent PREMIXRAW --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-RAW --fileout file:hlt.root --pileup_input "dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23_130X_mcRun3_2023_realistic_v13-v1/PREMIX" --conditions 130X_mcRun3_2023_realistic_v15 --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2023v12 --procModifiers premix_stage2 --geometry DB:Extended --filein file:gensim.root --datamix PreMix --era Run3_2023 --mc --nThreads $NTHREAD -n $NEVENT > digi.log 2>&1 || exit $? # for Run3Summer23
# cmsDriver.py  --python_filename DIGIPremix_cfg.py --eventcontent PREMIXRAW --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-RAW --fileout file:hlt.root --pileup_input "dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23BPix_130X_mcRun3_2023_realistic_postBPix_v1-v1/PREMIX" --conditions 130X_mcRun3_2023_realistic_postBPix_v6 --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2023v12 --procModifiers premix_stage2 --geometry DB:Extended --filein file:gensim.root --datamix PreMix --era Run3_2023 --mc --nThreads $NTHREAD -n $NEVENT > digi.log 2>&1 || exit $? # for Run3Summer23BPix
# using provided DIGIPremix cfg
if [ "$CAMPAIGN" == "Run3Summer23" ]; then
  cmsRun inputs/scripts/DIGIPremix_Run3_2023_template_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD
elif [ "$CAMPAIGN" == "Run3Summer23BPix" ]; then
  cmsRun inputs/scripts/DIGIPremix_Run3_2023BPix_template_cfg.py maxEvents=$NEVENT nThreads=$NTHREAD
fi

# begin RECO
cmsDriver.py  --python_filename RECO_cfg.py --eventcontent AODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier AODSIM --fileout file:reco.root --conditions $GLOBALTAG --step RAW2DIGI,L1Reco,RECO,RECOSIM --geometry DB:Extended --filein file:hlt.root --era Run3_2023 --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;

# Run MiniAODv2 with -j FrameworkJobReport.xml 
cmsDriver.py  --python_filename MiniAODv4_cfg.py --eventcontent MINIAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier MINIAODSIM --fileout file:miniv4.root --conditions $GLOBALTAG --step PAT --geometry DB:Extended --filein file:reco.root --era Run3_2023 --no_exec --mc --nThreads $NTHREAD -n $NEVENT || exit $? ;
cmsRun -j FrameworkJobReport.xml MiniAODv4_cfg.py
# Transfer file
xrdcp --silent -p -f miniv4.root $EOSPATH
touch dummy.cc

# # end of script
# EndOfTestFile

# # Make file executable
# chmod +x run_el8.sh

# if [ -e "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el8:amd64" ]; then
#   CONTAINER_NAME="el8:amd64"
# elif [ -e "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el8:x86_64" ]; then
#   CONTAINER_NAME="el8:x86_64"
# else
#   echo "Could not find amd64 or x86_64 for el8"
#   exit 1
# fi
# # Run in singularity container
# # Mount afs, eos, cvmfs
# # Mount /etc/grid-security for xrootd
# export SINGULARITY_CACHEDIR="/tmp/$(whoami)/singularity"
# singularity run -B /afs -B /eos -B /cvmfs -B /etc/grid-security -B /etc/pki/ca-trust --home $PWD:$PWD /cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/$CONTAINER_NAME $(echo $(pwd)/run_el8.sh "$@")
