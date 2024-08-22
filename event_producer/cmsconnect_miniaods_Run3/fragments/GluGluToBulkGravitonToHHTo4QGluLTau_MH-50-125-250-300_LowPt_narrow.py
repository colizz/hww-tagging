import FWCore.ParameterSet.Config as cms

#refering to https://cms-pdmv-prod.web.cern.ch/mcm/requests?prepid=BTV-Run3Summer23GS-00059&page=0&shown=262271
from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *

generator = cms.EDFilter("Pythia8GeneratorFilter",
    maxEventsToPrint = cms.untracked.int32(1),
    pythiaPylistVerbosity = cms.untracked.int32(1),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13000.), # special: ensure we have the same phase space with Run2 samples
    RandomizedParameters = cms.VPSet(),
)

# specify (MX, MH) points for test dataset
mpoints=[(973, 50), (1000, 125), (1090, 250), (1195, 350)]

for mx, mh in mpoints:
    # print('BulkGravitonToHH_MX%.0f_MH%.0f' % (mx, mh))
    generator.RandomizedParameters.append(
        cms.PSet(
            ConfigWeight = cms.double(1),
            GridpackPath =  cms.string('instMG://BulkGravitonToHH_MX-600to6000_MH-15to250/MG5_aMC_v2.9.18/%.0f:%.0f' % (mx, mh)),
            ConfigDescription = cms.string('BulkGravitonToHH_MX%.0f_MH%.0f' % (mx, mh)),
            PythiaParameters = cms.PSet(
                pythia8CommonSettingsBlock,
                pythia8CP5SettingsBlock,
                pythia8PSweightsSettingsBlock,
                processParameters = cms.vstring('25:onMode = off',
                                                '25:oneChannel = 1 0.12500 100 5 -5',
                                                '25:addChannel = 1 0.12500 100 4 -4',
                                                '25:addChannel = 1 0.12500 100 3 -3',
                                                '25:addChannel = 1 0.06250 100 2 -2',
                                                '25:addChannel = 1 0.06250 100 1 -1',
                                                '25:addChannel = 1 0.12500 100 21 21',
                                                '25:addChannel = 1 0.06250 100 11 -11',
                                                '25:addChannel = 1 0.06250 100 13 -13',
                                                '25:addChannel = 1 0.25000 100 15 -15',
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
