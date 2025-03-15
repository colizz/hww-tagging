str_fragment = r'''import FWCore.ParameterSet.Config as cms

from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *

pthat_list = [(170, 300), (300, 470), (470, 600), (600, 800), (800, 1000), (1000, 1400), (1400, 1800), (1800, 2400), (2400, 3200), (3200, 100000)]
ind = __IND__

source = cms.Source("EmptySource")
generator = cms.EDFilter('Pythia8ConcurrentGeneratorFilter',
        comEnergy = cms.double(13000.0), # still use Run 2 energy to keep the same as the previous production
        crossSection = cms.untracked.double(1000.0),
        filterEfficiency = cms.untracked.double(0.002),
        maxEventsToPrint = cms.untracked.int32(0),
        pythiaHepMCVerbosity = cms.untracked.bool(False),
        pythiaPylistVerbosity = cms.untracked.int32(0),

        PythiaParameters = cms.PSet(
        pythia8CommonSettingsBlock,
        pythia8CP5SettingsBlock,
            processParameters = cms.vstring(
            'PromptPhoton:qg2qgamma = on       ! prompt photon production',
            'PromptPhoton:qqbar2ggamma = on    ! prompt photon production',
            'PromptPhoton:gg2ggamma = on       ! prompt photon production',
            'PhaseSpace:pTHatMin = %d.         ! minimum pt hat for hard interactions' % pthat_list[ind][0], 
            'PhaseSpace:pTHatMax = %d.         ! maximum pt hat for hard interactions' % pthat_list[ind][1]),
            parameterSets = cms.vstring('pythia8CommonSettings',
                                        'pythia8CP5Settings',
                                        'processParameters')
            )
)

gj_filter = cms.EDFilter("PythiaFilterGammaGamma",
    PtSeedThr = cms.double(5.0),
    EtaSeedThr = cms.double(2.8),
    PtGammaThr = cms.double(0.0),
    EtaGammaThr = cms.double(2.8),
    PtElThr = cms.double(2.0),
    EtaElThr = cms.double(2.8),
    dRSeedMax = cms.double(0.0),
    dPhiSeedMax = cms.double(0.2),
    dEtaSeedMax = cms.double(0.12),
    dRNarrowCone = cms.double(0.02),
    PtTkThr = cms.double(1.6),
    EtaTkThr = cms.double(2.2),
    dRTkMax = cms.double(0.2),
    PtMinCandidate1 = cms.double(15.),
    PtMinCandidate2 = cms.double(15.),
    EtaMaxCandidate = cms.double(3.0),
    NTkConeMax = cms.int32(2),
    NTkConeSum = cms.int32(4),
    InvMassMin = cms.double(80.0),
    InvMassMax = cms.double(14000.0),
    EnergyCut = cms.double(1.0),
    AcceptPrompts = cms.bool(True),
    PromptPtThreshold = cms.double(15.0)   
    
    )
 
ProductionFilterSequence = cms.Sequence(generator*gj_filter)
'''

str_jdl = r'''Universe   = vanilla
Executable = run_and_transfer_haa.sh

+ProjectName="cms.org.cern"

# custom args
NEVENT = 5000
NEVENTLUMIBLOCK = 5000
NTHREAD = 1
PROCNAME = __PROCNAME__
EOSPATH = root://eoscms.cern.ch//store/cmst3/group/vhcc/sfTuples/$(PROCNAME)/24MiniAODv6/miniv6_$(Cluster)-$(Process).root

# note: use different seeds in different H->2prong and H->WW/ZZ routines to avoid overlap in LHE events
BEGINSEED = 10

Arguments = $(JOBNUM) $(NEVENT) $(NEVENTLUMIBLOCK) $(NTHREAD) $(PROCNAME) $(BEGINSEED) $(EOSPATH) $(LHEPRODSCRIPT)

#requirements = (OpSysAndVer =?= "CentOS8")
Requirements = HAS_SINGULARITY == True
+SingularityImage = "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el8:x86_64"
request_cpus = 1
request_memory = 2000
use_x509userproxy = true

+JobFlavour = "tomorrow"

Log        = log/job.log_$(Cluster)
Output     = log/job.out_$(Cluster)-$(Process)
Error      = log/job.err_$(Cluster)-$(Process)

should_transfer_files   = YES
when_to_transfer_output = ON_EXIT_OR_EVICT
transfer_output_files   = dummy.cc

Queue JOBNUM from seq 1 500 |'''

import os
for i, (ptmin, ptmax) in enumerate([(170, 300), (300, 470), (470, 600), (600, 800), (800, 1000), (1000, 1400), (1400, 1800), (1800, 2400), (2400, 3200), (3200, 100000)]):
    if ptmax == 100000:
        ptmax = "Inf"
    with open(f"fragments/GJet_PT-{ptmin}to{ptmax}_DoubleEMEnriched_MGG-80_TuneCP5_13TeV_pythia8.py", "w") as f:
        f.write(str_fragment.replace("__IND__", str(i)))

    with open(f"jdl/train/submit_qcdaa{i}.jdl", "w") as f:
        f.write(str_jdl.replace("__PROCNAME__", f"GJet_PT-{ptmin}to{ptmax}_DoubleEMEnriched_MGG-80_TuneCP5_13TeV_pythia8"))
