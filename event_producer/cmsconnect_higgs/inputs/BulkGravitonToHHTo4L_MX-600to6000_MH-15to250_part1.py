import FWCore.ParameterSet.Config as cms
#Link to datacards:
#https://github.com/cms-sw/genproductions/tree/master/bin/MadGraph5_aMCatNLO/cards/production/2017/13TeV/BulkGraviton_hh_granular
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

model = "BulkGraviton_hh_GF_HH_narrow"
mpoints=[]
mH_l=15
mH_r=250
mH_step=10
mX_l=600
mX_r=6000
mX_step=300
mX_tmp=mX_l
while mX_tmp <= mX_r:
        mH_tmp=mH_l;
        while mH_tmp <=mH_r:
                mpoints.append([mX_tmp,mH_tmp]);
		if mH_tmp < 30: mH_step=5;
		else: mH_step=10;
                mH_tmp+=mH_step;
        mX_tmp+=mX_step;

for point in mpoints:
    generator.RandomizedParameters.append(
        cms.PSet(
            ConfigWeight = cms.double(1),
            GridpackPath =  cms.string('/cvmfs/cms.cern.ch/phys_generator/gridpacks/2017/13TeV/madgraph/V5_2.6.5/BulkGraviton_hh_GF_HH_part1/%s_MX%s_MH%s_slc6_amd64_gcc630_CMSSW_9_3_16_tarball.tar.xz' % (model,point[0], point[1])),
            ConfigDescription = cms.string('%s_MX%s_MH%s' % (model, point[0], point[1])),
            PythiaParameters = cms.PSet(
                pythia8CommonSettingsBlock,
                pythia8CP5SettingsBlock,
                pythia8PSweightsSettingsBlock,
                processParameters = cms.vstring('25:onMode = off',
                                                '25:oneChannel = 1 0.50000 100 11 -11',
                                                '25:addChannel = 1 0.50000 100 13 -13',
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


