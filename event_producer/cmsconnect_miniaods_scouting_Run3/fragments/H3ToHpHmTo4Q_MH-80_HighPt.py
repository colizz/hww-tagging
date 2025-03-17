import FWCore.ParameterSet.Config as cms

#Link to datacards:
#refering to https://cms-pdmv-prod.web.cern.ch/mcm/requests?prepid=BTV-Run3Summer23GS-00059&page=0&shown=262271
from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *

generator = cms.EDFilter("Pythia8GeneratorFilter",
    maxEventsToPrint = cms.untracked.int32(1),
    pythiaPylistVerbosity = cms.untracked.int32(1),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13600.),
    RandomizedParameters = cms.VPSet(),
)

# specify (MX, MH) points for test dataset
mpoints=[(2493, 80)]

for mx, mh in mpoints:
    generator.RandomizedParameters.append(
        cms.PSet(
            ConfigWeight = cms.double(1),
            GridpackPath =  cms.string('instMG://H3ToHpHm/MG5_aMC_v2.9.18/%.0f:%.0f' % (mx, mh)),
            ConfigDescription = cms.string('H3ToHpHm_MX%.0f_MH%.0f' % (mx, mh)),
            PythiaParameters = cms.PSet(
                pythia8CommonSettingsBlock,
                pythia8CP5SettingsBlock,
                pythia8PSweightsSettingsBlock,
                processParameters = cms.vstring('37:onMode = off',
                                                '37:oneChannel = 1 0.33333 100 5 -4',
                                                '37:addChannel = 1 0.33333 100 3 -4',
                                                '37:addChannel = 1 0.33334 100 1 -2',
                                                'ResonanceDecayFilter:filter = on'
                ),
                parameterSets = cms.vstring('pythia8CommonSettings',
                                            'pythia8CP5Settings',
                                            'pythia8PSweightsSettings',
                                            'processParameters',
		        )
            )
        )
    )
