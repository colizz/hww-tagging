# offical fragment https://cms-pdmv-prod.web.cern.ch/mcm/requests?page=0&dataset_name=QCD*&prepid=*Summer23GS*&shown=262271
# for profiling

import FWCore.ParameterSet.Config as cms

from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *

generator = cms.EDFilter("Pythia8ConcurrentGeneratorFilter",
	maxEventsToPrint = cms.untracked.int32(1),
	pythiaPylistVerbosity = cms.untracked.int32(1),
	filterEfficiency = cms.untracked.double(1.0),
	pythiaHepMCVerbosity = cms.untracked.bool(False),
	comEnergy = cms.double(13600.0),

	PythiaParameters = cms.PSet(
            pythia8CommonSettingsBlock,
            pythia8CP5SettingsBlock,
	    processParameters = cms.vstring(
			'HardQCD:all = on',
			'PhaseSpace:pTHatMin = 3200  ',
	    ),
            parameterSets = cms.vstring('pythia8CommonSettings',
                                        'pythia8CP5Settings',
                                        'processParameters',
                                        )
	)
)

configurationMetadata = cms.untracked.PSet(
    version = cms.untracked.string('\$Revision$'),
    name = cms.untracked.string('\$Source$'),
    annotation = cms.untracked.string('QCD pthat 3200toInf GeV, 13.6 TeV, TuneCP5')
)
