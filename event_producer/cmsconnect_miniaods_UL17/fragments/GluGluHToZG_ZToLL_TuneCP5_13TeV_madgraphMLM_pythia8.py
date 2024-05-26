import FWCore.ParameterSet.Config as cms

# link to example datacards of 125 mass point:
# https://github.com/cms-sw/genproductions/tree/master/bin/MadGraph5_aMCatNLO/cards/production/2017/13TeV/ggh01j_M125_HiggsPt120toInf/

#Link to GS fragment
from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunes2017.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *

generator = cms.EDFilter("Pythia8GeneratorFilter",
    maxEventsToPrint = cms.untracked.int32(1),
    pythiaPylistVerbosity = cms.untracked.int32(1),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13000.),
    RandomizedParameters = cms.VPSet(),
)

import numpy as np
m_higgs = np.arange(95, 185, 1)

for mh in m_higgs:
    generator.RandomizedParameters.append(
        cms.PSet(
            ConfigWeight = cms.double(1),
            GridpackPath =  cms.string('instMG://GluGluHToZG_ZToLL_TuneCP5_13TeV_madgraphMLM_pythia8/MG5_aMC_v2.6.5/%.0f' % (mh)),
            ConfigDescription = cms.string('GluGluHToZG_ZToLL_M%.0f_TuneCP5_13TeV_madgraphMLM_pythia8' % (mh)),
            PythiaParameters = cms.PSet(
                pythia8CommonSettingsBlock,
                pythia8CP5SettingsBlock,
                pythia8PSweightsSettingsBlock,
                processParameters = cms.vstring(
                    'JetMatching:setMad = off',
                    'JetMatching:scheme = 1',
                    'JetMatching:merge = on',
                    'JetMatching:jetAlgorithm = 2',
                    'JetMatching:etaJetMax = 999.',
                    'JetMatching:coneRadius = 1.',
                    'JetMatching:slowJetPower = 1',
                    'JetMatching:qCut = 15.', #this is the actual merging scale
                    'JetMatching:nQmatch = 5', #4 corresponds to 4-flavour scheme (no matching of b-quarks), 5 for 5-flavour scheme
                    'JetMatching:nJetMax = 1', #number of partons in born matrix element for highest multiplicity
                    'JetMatching:doShowerKt = off', #off for MLM matching, turn on for shower-kT matching
                ),
                parameterSets = cms.vstring('pythia8CommonSettings',
                                            'pythia8CP5Settings',
                                            'pythia8PSweightsSettings',
		        )
            )
        )
    )
